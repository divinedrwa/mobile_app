import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/parcel_model.dart';
import '../repositories/parcel_repository.dart';

/// Parcel State Notifier
class ParcelNotifier extends StateNotifier<AsyncValue<List<ParcelModel>>> {
  final ParcelRepository _repository;

  ParcelNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchParcels();
  }

  /// Fetch all parcels
  Future<void> fetchParcels() async {
    state = const AsyncValue.loading();
    try {
      final parcels = await _repository.getParcels();
      state = AsyncValue.data(parcels);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Fetch pending parcels only
  Future<void> fetchPendingParcels() async {
    state = const AsyncValue.loading();
    try {
      final parcels = await _repository.getPendingParcels();
      state = AsyncValue.data(parcels);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Mark parcel as collected.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> markAsCollected(String parcelId) async {
    try {
      await _repository.markAsCollected(parcelId);
      await fetchParcels();
      return null;
    } catch (e) {
      debugPrint('Error marking parcel as collected: $e');
      return e is AppException ? e.message : 'Something went wrong. Please try again.';
    }
  }

  /// Get pending count
  int getPendingCount() {
    return state.when(
      data: (parcels) => parcels.where((p) => p.status == ParcelStatus.pending).length,
      loading: () => 0,
      error: (_, _) => 0,
    );
  }
}

/// Parcel Provider
final parcelProvider = StateNotifierProvider<ParcelNotifier, AsyncValue<List<ParcelModel>>>(
  (ref) => ParcelNotifier(ParcelRepository()),
);

/// Pending parcels count provider
final pendingParcelsCountProvider = Provider<int>((ref) {
  return ref.watch(parcelProvider).when(
        data: (parcels) => parcels.where((p) => p.status == ParcelStatus.pending).length,
        loading: () => 0,
        error: (_, _) => 0,
      );
});
