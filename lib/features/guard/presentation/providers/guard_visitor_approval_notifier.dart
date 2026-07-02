import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../data/models/guard_models.dart';
import 'guard_providers.dart';

/// Immutable snapshot of the visitor-approval form's non-text-field state.
@immutable
class VisitorApprovalFormState {
  const VisitorApprovalFormState({
    this.resident,
    this.submittingOtp = false,
    this.submittingNotify = false,
    this.submittingAllow = false,
    this.otpVerified,
    this.admittingPreApprovedId,
  });

  final ResidentPickerItem? resident;
  final bool submittingOtp;
  final bool submittingNotify;
  final bool submittingAllow;
  final bool? otpVerified;
  final String? admittingPreApprovedId;

  VisitorApprovalFormState copyWith({
    ResidentPickerItem? resident,
    bool clearResident = false,
    bool? submittingOtp,
    bool? submittingNotify,
    bool? submittingAllow,
    bool? otpVerified,
    bool clearOtpVerified = false,
    String? admittingPreApprovedId,
    bool clearAdmitting = false,
  }) {
    return VisitorApprovalFormState(
      resident: clearResident ? null : (resident ?? this.resident),
      submittingOtp: submittingOtp ?? this.submittingOtp,
      submittingNotify: submittingNotify ?? this.submittingNotify,
      submittingAllow: submittingAllow ?? this.submittingAllow,
      otpVerified:
          clearOtpVerified ? null : (otpVerified ?? this.otpVerified),
      admittingPreApprovedId: clearAdmitting
          ? null
          : (admittingPreApprovedId ?? this.admittingPreApprovedId),
    );
  }
}

/// Result from an action — the widget uses this to show snackbars / navigate.
@immutable
class ApprovalActionResult {
  const ApprovalActionResult({
    required this.success,
    this.message,
  });
  final bool success;
  final String? message;
}

class VisitorApprovalFormNotifier
    extends StateNotifier<VisitorApprovalFormState> {
  VisitorApprovalFormNotifier(this._ref)
      : super(const VisitorApprovalFormState());

  final Ref _ref;

  void selectResident(ResidentPickerItem? resident) {
    state = state.copyWith(
      resident: resident,
      clearResident: resident == null,
      clearOtpVerified: true,
    );
  }

  /// Verifies OTP for the selected resident's villa.
  /// [fallbackVillaId] is used when no resident is selected (e.g. from QR scan payload).
  /// Returns an [ApprovalActionResult].
  Future<ApprovalActionResult> verifyOtp({
    required String otp,
    String? fallbackVillaId,
  }) async {
    final resident = state.resident;
    final villaId = resident?.villaId ?? fallbackVillaId;
    if (villaId == null || villaId.isEmpty) {
      return const ApprovalActionResult(
        success: false,
        message: 'Select a resident first',
      );
    }
    if (otp.trim().length < 4) {
      return const ApprovalActionResult(
        success: false,
        message: 'Enter OTP from resident',
      );
    }

    state = state.copyWith(submittingOtp: true, clearOtpVerified: true);
    try {
      final res = await _ref
          .read(guardRepositoryProvider)
          .verifyVisitorOtp(otp: otp.trim(), villaId: villaId);
      final ok = res['verified'] == true;
      state = state.copyWith(submittingOtp: false, otpVerified: ok);
      return ApprovalActionResult(
        success: ok,
        message: ok
            ? 'OTP verified'
            : (res['message']?.toString() ?? 'Verification failed'),
      );
    } catch (e) {
      state = state.copyWith(submittingOtp: false, otpVerified: false);
      return ApprovalActionResult(
        success: false,
        message: userFacingMessage(e),
      );
    }
  }

  /// Sends a push notification to the selected flat's residents.
  Future<ApprovalActionResult> notifyResident({
    required String visitorName,
    required String visitorPhone,
  }) async {
    // Require an explicit selection — never fall back to "the first resident in
    // the society", which would ping an arbitrary unrelated household.
    final resident = state.resident;
    if (resident == null) {
      return const ApprovalActionResult(
        success: false,
        message: 'Select a resident first',
      );
    }
    if (visitorName.trim().isEmpty || visitorPhone.trim().isEmpty) {
      return const ApprovalActionResult(
        success: false,
        message: 'Enter visitor name and phone',
      );
    }

    state = state.copyWith(submittingNotify: true);
    final span = GuardFlowTelemetry.start('guard_notify_visitor_at_gate');
    try {
      await _ref.read(guardRepositoryProvider).notifyVisitorAtGate(
            villaId: resident.villaId,
            visitorName: visitorName.trim(),
            visitorPhone: visitorPhone.trim(),
          );
      span.complete();
      state = state.copyWith(submittingNotify: false);
      return const ApprovalActionResult(
        success: true,
        message: 'Flat residents were notified',
      );
    } catch (e) {
      span.complete(success: false);
      state = state.copyWith(submittingNotify: false);
      return ApprovalActionResult(
        success: false,
        message: userFacingMessage(e),
      );
    }
  }

  /// OTP-based gate entry: verifies + creates visitor in one call.
  /// [fallbackVillaId] is used when no resident is selected (e.g. from QR scan payload).
  Future<ApprovalActionResult> allowEntry({
    required String otp,
    required String visitorName,
    required String visitorPhone,
    String? fallbackVillaId,
  }) async {
    final resident = state.resident;
    final villaId = resident?.villaId ?? fallbackVillaId;
    if (villaId == null || villaId.isEmpty) {
      return const ApprovalActionResult(
        success: false,
        message: 'Select a resident',
      );
    }
    if (otp.trim().length < 4) {
      return const ApprovalActionResult(
        success: false,
        message: 'Enter OTP to allow gate entry',
      );
    }

    state = state.copyWith(submittingAllow: true);
    final span = GuardFlowTelemetry.start('guard_allow_entry');
    try {
      final res = await _ref.read(guardRepositoryProvider).approveVisitorEntry(
            otp: otp.trim(),
            villaId: villaId,
            visitorName: visitorName.trim(),
            visitorPhone: visitorPhone.trim(),
          );
      final admitted = res['admitted'] == true || res['verified'] == true;
      if (admitted) {
        span.complete();
        _invalidateDashboardProviders();
      } else {
        span.complete(success: false);
      }
      state = state.copyWith(submittingAllow: false);
      return ApprovalActionResult(
        success: admitted,
        message: res['message']?.toString() ??
            (admitted ? 'Visitor admitted and checked in' : 'Entry not allowed'),
      );
    } catch (e) {
      span.complete(success: false);
      state = state.copyWith(submittingAllow: false);
      return ApprovalActionResult(
        success: false,
        message: userFacingMessage(e),
      );
    }
  }

  /// One-tap admit for a pre-approved entry.
  Future<ApprovalActionResult> admitPreApproved(String entryId) async {
    state = state.copyWith(admittingPreApprovedId: entryId);
    final span = GuardFlowTelemetry.start(
      'guard_admit_preapproved_from_approval',
    );
    try {
      final map = await _ref
          .read(guardRepositoryProvider)
          .admitPreApprovedEntry(entryId);
      final admitted = map['admitted'] == true;
      if (admitted) {
        span.complete();
        _invalidateDashboardProviders();
      } else {
        span.complete(success: false);
      }
      state = state.copyWith(clearAdmitting: true);
      return ApprovalActionResult(
        success: admitted,
        message: map['message']?.toString(),
      );
    } catch (e) {
      span.complete(success: false);
      state = state.copyWith(clearAdmitting: true);
      return ApprovalActionResult(
        success: false,
        message: userFacingMessage(e, 'Could not admit visitor.'),
      );
    }
  }

  void _invalidateDashboardProviders() {
    _ref.invalidate(guardDashboardProvider);
    _ref.invalidate(guardTodayVisitorsProvider);
    _ref.invalidate(guardPendingVisitorsProvider);
    _ref.invalidate(guardActiveVisitorsTabProvider);
    _ref.invalidate(guardPreApprovedEntriesProvider);
  }
}

final visitorApprovalFormProvider = StateNotifierProvider.autoDispose<
    VisitorApprovalFormNotifier, VisitorApprovalFormState>(
  (ref) => VisitorApprovalFormNotifier(ref),
);
