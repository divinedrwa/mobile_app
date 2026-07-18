import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../data/guard_visitor_type.dart';
import '../../data/offline_queue_service.dart';
import '../../utils/shift_active_helper.dart';
import 'guard_command_providers.dart';
import 'guard_offline_sync_notifier.dart';
import 'guard_providers.dart';

/// Immutable snapshot of the check-in form's non-text-field state.
@immutable
class CheckInFormState {
  const CheckInFormState({
    this.visitorType = GuardCheckInVisitorType.guest,
    this.selectedUserIds = const {},
    this.photoBytes,
    this.submitting = false,
    this.errorMessage,
    this.submitted = false,
    this.resultMessage,
  });

  final GuardCheckInVisitorType visitorType;
  final Set<String> selectedUserIds;
  final Uint8List? photoBytes;
  final bool submitting;
  final String? errorMessage;
  final bool submitted;
  final String? resultMessage;

  int get selectedCount => selectedUserIds.length;

  CheckInFormState copyWith({
    GuardCheckInVisitorType? visitorType,
    Set<String>? selectedUserIds,
    Uint8List? photoBytes,
    bool clearPhoto = false,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
    bool? submitted,
    String? resultMessage,
  }) {
    return CheckInFormState(
      visitorType: visitorType ?? this.visitorType,
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
      photoBytes: clearPhoto ? null : (photoBytes ?? this.photoBytes),
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitted: submitted ?? this.submitted,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
}

class CheckInFormNotifier extends StateNotifier<CheckInFormState> {
  CheckInFormNotifier(this._ref) : super(const CheckInFormState());

  final Ref _ref;

  void setVisitorType(GuardCheckInVisitorType type) {
    state = state.copyWith(visitorType: type, clearError: true);
  }

  void toggleResident(String userId) {
    final ids = Set<String>.from(state.selectedUserIds);
    if (ids.contains(userId)) {
      ids.remove(userId);
    } else {
      ids.add(userId);
    }
    state = state.copyWith(selectedUserIds: ids, clearError: true);
  }

  /// Select/deselect a whole flat: toggles all of the flat's resident user ids
  /// together. Selecting a flat targets every occupant (they all get notified).
  /// Toggles OFF only when every occupant is already selected, otherwise ON.
  void toggleFlat(Iterable<String> flatUserIds) {
    final flat = flatUserIds.toSet();
    if (flat.isEmpty) return;
    final ids = Set<String>.from(state.selectedUserIds);
    final allSelected = flat.every(ids.contains);
    if (allSelected) {
      ids.removeAll(flat);
    } else {
      ids.addAll(flat);
    }
    state = state.copyWith(selectedUserIds: ids, clearError: true);
  }

  void clearResidents() {
    state = state.copyWith(selectedUserIds: const {});
  }

  static const _maxPhotoBytes = 180000;

  Future<bool> pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 68,
    );
    if (x == null) return false;
    final bytes = await x.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      state = state.copyWith(
        errorMessage: 'Image too large — pick a smaller photo or skip.',
      );
      return false;
    }
    state = state.copyWith(photoBytes: bytes, clearError: true);
    return true;
  }

  void clearPhoto() {
    state = state.copyWith(clearPhoto: true);
  }

  String? _photoForApi() {
    if (state.photoBytes == null || state.photoBytes!.isEmpty) return null;
    if (state.photoBytes!.length > 160000) return null;
    return 'data:image/jpeg;base64,${base64Encode(state.photoBytes!)}';
  }

  /// Validates and submits the form. Returns null on success or an error
  /// message string. Text field values are passed in since controllers live
  /// in the widget.
  Future<String?> submit({
    required String name,
    required String phone,
    required String? vehicleNumber,
  }) async {
    state = state.copyWith(clearError: true);

    // Check active shift.
    try {
      final shifts = await _ref.read(guardMyShiftsProvider.future);
      final hasShift = ShiftActiveHelper.hasActiveShift(
        shifts.map((r) => r.toRawMap()).toList(),
      );
      if (!hasShift) {
        const msg =
            'No active shift found. Ask admin to assign/start your shift first.';
        state = state.copyWith(errorMessage: msg);
        return msg;
      }
    } catch (_) {
      // Let it pass if shift check fails — don't block check-in.
    }

    if (state.selectedUserIds.isEmpty) {
      const msg = 'Select at least one resident';
      state = state.copyWith(errorMessage: msg);
      return msg;
    }

    state = state.copyWith(submitting: true);

    final span = GuardFlowTelemetry.start('guard_check_in');
    try {
      final allResidents =
          _ref.read(guardResidentsPickerProvider).valueOrNull ?? [];
      // One target per selected FLAT (villa), not per resident. The flat picker
      // selects whole flats, so collapse to the villa: this avoids the
      // VisitorVilla @@unique([visitorId,villaId,unitId]) collision when
      // occupants share a unit, and targets the whole flat (the backend
      // resolves the default unit and notifies every occupant).
      final targets = <String>{
        for (final r in allResidents)
          if (state.selectedUserIds.contains(r.userId)) r.villaId,
      }.map((vid) => VisitTarget(villaId: vid)).toList();

      final params = GuardCheckInSubmitParams(
        name: name,
        phone: phone,
        visitTargets: targets,
        visitorTypeApi: state.visitorType.apiValue,
        vehicleNumber: vehicleNumber,
        photo: _photoForApi(),
      );

      final result =
          await _ref.read(guardCheckInSubmitProvider)(params);
      span.complete();

      // Invalidate related providers.
      _ref.invalidate(guardDashboardProvider);
      _ref.invalidate(guardTodayVisitorsProvider);
      _ref.invalidate(guardPendingVisitorsProvider);
      _ref.invalidate(guardActiveVisitorsTabProvider);
      _ref.invalidate(guardPreApprovedEntriesProvider);

      // Build result message.
      String resultMsg;
      if (params.awaitResidentApproval) {
        final count = result['residentApprovalRecipientCount'];
        if (count is int && count == 0) {
          resultMsg =
              'Request created, but no resident account is mapped to selected flat(s). '
              'Approval will not be possible until mapping is fixed.';
        } else {
          resultMsg =
              'Request sent to residents. They can approve or reject in the app. '
              "You'll get a notification when it's decided.";
        }
      } else {
        resultMsg = 'Visitor checked in';
      }

      state = state.copyWith(
        submitting: false,
        submitted: true,
        resultMessage: resultMsg,
      );
      return null;
    } catch (e) {
      span.complete(success: false);

      // On network failure, queue for offline sync.
      if (e is NetworkException) {
        final allResidents =
            _ref.read(guardResidentsPickerProvider).valueOrNull ?? [];
        // Same whole-flat collapse as the online path (one target per villa).
        final targets = <String>{
          for (final r in allResidents)
            if (state.selectedUserIds.contains(r.userId)) r.villaId,
        }.map((vid) => VisitTarget(villaId: vid).toJson()).toList();
        final clientMutationId = const Uuid().v4();
        final mutation = OfflineMutation(
          id: clientMutationId,
          type: OfflineMutationType.visitorCheckIn,
          params: {
            'name': name,
            'phone': phone,
            'visitTargets': targets,
            'visitorTypeApi': state.visitorType.apiValue,
            'awaitResidentApproval': true,
            'clientMutationId': clientMutationId,
            if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
            if (_photoForApi() != null) 'photo': _photoForApi(),
          },
          createdAt: DateTime.now(),
        );
        await _ref.read(offlineSyncProvider.notifier).enqueue(mutation);
        state = state.copyWith(
          submitting: false,
          submitted: true,
          resultMessage:
              'Saved offline — will sync automatically when back online.',
        );
        return null;
      }

      final msg = guardCommandErrorMessage(e);
      state = state.copyWith(submitting: false, errorMessage: msg);
      return msg;
    }
  }
}

final checkInFormProvider =
    StateNotifierProvider.autoDispose<CheckInFormNotifier, CheckInFormState>(
  (ref) => CheckInFormNotifier(ref),
);
