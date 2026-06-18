import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminAmenityRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getAmenities() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminAmenities);
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['amenities'] is List) {
        return (data['amenities'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load amenities');
    }
  }

  Future<Map<String, dynamic>> createAmenity({
    required String name,
    required String type,
    String? description,
    int? capacity,
    double? pricePerHour,
    bool isActive = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminAmenities,
        data: {
          'name': name,
          'type': type, // required by the backend (AmenityType enum)
          if (description != null && description.isNotEmpty)
            'description': description,
          if (capacity != null) 'capacity': capacity,
          if (pricePerHour != null) 'pricePerHour': pricePerHour,
          'isActive': isActive,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create amenity');
    }
  }

  Future<Map<String, dynamic>> updateAmenity(
    String id, {
    String? name,
    String? type,
    String? description,
    int? capacity,
    double? pricePerHour,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.adminAmenityById(id),
        data: {
          if (name != null) 'name': name,
          if (type != null) 'type': type,
          if (description != null) 'description': description,
          if (capacity != null) 'capacity': capacity,
          if (pricePerHour != null) 'pricePerHour': pricePerHour,
          if (isActive != null) 'isActive': isActive,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update amenity');
    }
  }
}
