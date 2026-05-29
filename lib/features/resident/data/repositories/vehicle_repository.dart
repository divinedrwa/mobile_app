import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/vehicle_model.dart';

/// Repository for vehicle operations
class VehicleRepository {
  Dio get _dio => DioClient.dio;

  /// Get all vehicles
  Future<List<VehicleModel>> getVehicles() async {
    try {
      final response = await _dio.get(ApiEndpoints.vehicles);

      // Backend returns { "vehicles": [...], "count": 0 }
      final vehiclesList = response.data['vehicles'] as List? ?? [];

      return vehiclesList.map((json) => VehicleModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch vehicles');
    }
  }

  /// Add vehicle
  Future<VehicleModel> addVehicle({
    required String vehicleNumber,
    required String type,
    String? brand,
    String? model,
    String? color,
  }) async {
    try {
      String apiType;
      switch (type.toLowerCase()) {
        case 'bike':
        case 'scooter':
        case 'two_wheeler':
          apiType = 'TWO_WHEELER';
          break;
        case 'truck':
        case 'heavy_vehicle':
          apiType = 'HEAVY_VEHICLE';
          break;
        default:
          apiType = 'FOUR_WHEELER';
      }
      final response = await _dio.post(
        ApiEndpoints.registerVehicle,
        data: {
          'registrationNumber': vehicleNumber,
          'type': apiType,
          'make': ?brand,
          'model': ?model,
          'color': ?color,
        },
      );

      return VehicleModel.fromJson(response.data['vehicle']);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to add vehicle');
    }
  }

  /// Update vehicle (backend accepts: make, model, color, parkingSlot)
  Future<VehicleModel> updateVehicle({
    required String id,
    String? brand,
    String? model,
    String? color,
    String? parkingSlot,
  }) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.updateVehicle(id),
        data: {
          'make': ?brand,
          'model': ?model,
          'color': ?color,
          'parkingSlot': ?parkingSlot,
        },
      );

      return VehicleModel.fromJson(response.data['vehicle']);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update vehicle');
    }
  }

  /// Delete vehicle
  Future<void> deleteVehicle(String id) async {
    try {
      await _dio.delete(ApiEndpoints.deleteVehicle(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete vehicle');
    }
  }
}
