import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminParkingRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getOverview() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.parkingOverview,
      );
      final data = res.data ?? {};
      // Backend nests slot counts under `summary`; expose the flat keys the
      // screen reads (totalSlots / occupiedSlots / availableSlots).
      final summary = (data['summary'] as Map?) ?? const {};
      return {
        ...Map<String, dynamic>.from(data),
        'totalSlots': summary['totalSlots'] ?? 0,
        'occupiedSlots': summary['occupiedSlots'] ?? 0,
        'availableSlots': summary['availableSlots'] ?? 0,
      };
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load parking overview');
    }
  }

  /// `{slots: [{slot, status, vehicleCount, vehicles}], unassignedVehicles, summary}`.
  Future<Map<String, dynamic>> getSlotAnalysis() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.parkingSlotAnalysis,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load parking slots');
    }
  }

  /// `{villaVehicles: [{villaNumber, block, ownerName, vehicleCount, vehicles}], summary}`.
  Future<Map<String, dynamic>> getVillaVehicles() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.parkingVillaVehicles,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load vehicles by villa');
    }
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminVehicles);
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['vehicles'] is List) {
        return (data['vehicles'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load vehicles');
    }
  }

  Future<Map<String, dynamic>> registerVehicle({
    required String registrationCategory,
    required String vehicleNumber,
    required String vehicleType,
    String? villaId,
    String? model,
    String? color,
    String? parkingSlot,
    String? ownerLabel,
    String? notes,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminVehicles,
        data: {
          'registrationCategory': registrationCategory,
          'vehicleNumber': vehicleNumber.trim().toUpperCase(),
          'vehicleType': vehicleType,
          if (villaId != null && villaId.isNotEmpty) 'villaId': villaId,
          if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          if (color != null && color.trim().isNotEmpty) 'color': color.trim(),
          if (parkingSlot != null && parkingSlot.trim().isNotEmpty)
            'parkingSlot': parkingSlot.trim(),
          if (ownerLabel != null && ownerLabel.trim().isNotEmpty)
            'ownerLabel': ownerLabel.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      final data = res.data;
      if (data != null) {
        final vehicle = data['vehicle'];
        if (vehicle is Map) {
          return Map<String, dynamic>.from(vehicle);
        }
        return data;
      }
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to register vehicle');
    }
  }

  Future<void> updateVehicle(
    String id, {
    String? vehicleNumber,
    String? vehicleType,
    String? model,
    String? color,
    String? parkingSlot,
    String? ownerLabel,
    String? notes,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminVehicleById(id),
        data: {
          if (vehicleNumber != null)
            'vehicleNumber': vehicleNumber.trim().toUpperCase(),
          if (vehicleType != null) 'vehicleType': vehicleType,
          if (model != null) 'model': model.trim(),
          if (color != null) 'color': color.trim(),
          if (parkingSlot != null) 'parkingSlot': parkingSlot.trim(),
          if (ownerLabel != null) 'ownerLabel': ownerLabel.trim(),
          if (notes != null) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update vehicle');
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminVehicleById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete vehicle');
    }
  }
}
