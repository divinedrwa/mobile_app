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
}
