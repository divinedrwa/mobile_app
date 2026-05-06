import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository.dart';

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

  /// Add vehicle
  Future<bool> addVehicle({
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
      return true;
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      return false;
    }
  }

  /// Update vehicle
  Future<bool> updateVehicle({
    required String id,
    String? vehicleNumber,
    String? type,
    String? brand,
    String? model,
    String? color,
  }) async {
    try {
      await _repository.updateVehicle(
        id: id,
        vehicleNumber: vehicleNumber,
        type: type,
        brand: brand,
        model: model,
        color: color,
      );
      await fetchVehicles();
      return true;
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      return false;
    }
  }

  /// Delete vehicle
  Future<bool> deleteVehicle(String id) async {
    try {
      await _repository.deleteVehicle(id);
      await fetchVehicles();
      return true;
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      return false;
    }
  }
}

/// Vehicle Provider
final vehicleProvider = StateNotifierProvider<VehicleNotifier, AsyncValue<List<VehicleModel>>>(
  (ref) => VehicleNotifier(VehicleRepository()),
);
