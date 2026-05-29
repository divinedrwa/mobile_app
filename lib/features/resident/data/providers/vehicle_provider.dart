import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository.dart';

String _errorMessage(Object e) {
  if (e is AppException) return e.message;
  return 'Something went wrong. Please try again.';
}

/// Vehicle State Notifier
class VehicleNotifier extends StateNotifier<AsyncValue<List<VehicleModel>>> {
  final VehicleRepository _repository;

  VehicleNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchVehicles();
  }

  /// Fetch all vehicles
  Future<void> fetchVehicles() async {
    state = const AsyncValue.loading();
    try {
      final vehicles = await _repository.getVehicles();
      state = AsyncValue.data(vehicles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add vehicle. Returns null on success, error message on failure.
  Future<String?> addVehicle({
    required String vehicleNumber,
    required String type,
    String? brand,
    String? model,
    String? color,
  }) async {
    try {
      await _repository.addVehicle(
        vehicleNumber: vehicleNumber,
        type: type,
        brand: brand,
        model: model,
        color: color,
      );
      await fetchVehicles();
      return null;
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      return _errorMessage(e);
    }
  }

  /// Update vehicle. Returns null on success, error message on failure.
  Future<String?> updateVehicle({
    required String id,
    String? brand,
    String? model,
    String? color,
    String? parkingSlot,
  }) async {
    try {
      await _repository.updateVehicle(
        id: id,
        brand: brand,
        model: model,
        color: color,
        parkingSlot: parkingSlot,
      );
      await fetchVehicles();
      return null;
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      return _errorMessage(e);
    }
  }

  /// Delete vehicle. Returns null on success, error message on failure.
  Future<String?> deleteVehicle(String id) async {
    try {
      await _repository.deleteVehicle(id);
      await fetchVehicles();
      return null;
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      return _errorMessage(e);
    }
  }
}

/// Vehicle Provider
final vehicleProvider = StateNotifierProvider<VehicleNotifier, AsyncValue<List<VehicleModel>>>(
  (ref) => VehicleNotifier(VehicleRepository()),
);
