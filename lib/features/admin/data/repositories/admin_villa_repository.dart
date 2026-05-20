import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminVillaRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all villas for the society.
  Future<List<Map<String, dynamic>>> getVillas() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminVillas);
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['villas'] is List) {
        return (data['villas'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load villas');
    }
  }

  /// Create a new villa.
  Future<Map<String, dynamic>> createVilla({
    required String villaNumber,
    int? floors,
    String? block,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    double? monthlyMaintenance,
    int? units,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminVillas,
        data: {
          'villaNumber': villaNumber,
          if (floors != null) 'floors': floors,
          if (block != null && block.isNotEmpty) 'block': block,
          if (ownerName != null && ownerName.isNotEmpty) 'ownerName': ownerName,
          if (ownerPhone != null && ownerPhone.isNotEmpty)
            'ownerPhone': ownerPhone,
          if (ownerEmail != null && ownerEmail.isNotEmpty)
            'ownerEmail': ownerEmail,
          if (monthlyMaintenance != null)
            'monthlyMaintenance': monthlyMaintenance,
          if (units != null) 'units': units,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create villa');
    }
  }

  /// Update an existing villa.
  Future<Map<String, dynamic>> updateVilla(
    String id, {
    String? villaNumber,
    int? floors,
    String? block,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    double? monthlyMaintenance,
    int? units,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.adminVillaById(id),
        data: {
          if (villaNumber != null) 'villaNumber': villaNumber,
          if (floors != null) 'floors': floors,
          if (block != null) 'block': block,
          if (ownerName != null) 'ownerName': ownerName,
          if (ownerPhone != null) 'ownerPhone': ownerPhone,
          if (ownerEmail != null) 'ownerEmail': ownerEmail,
          if (monthlyMaintenance != null)
            'monthlyMaintenance': monthlyMaintenance,
          if (units != null) 'units': units,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update villa');
    }
  }

  /// Delete a villa.
  Future<void> deleteVilla(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminVillaById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete villa');
    }
  }
}
