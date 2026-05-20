import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminResidentManagementRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch resident overview with full list + statistics.
  Future<Map<String, dynamic>> getOverview() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.residentManagementOverview,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load resident overview');
    }
  }

  /// Fetch resident statistics (active, inactive, owners, tenants, etc.).
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.residentManagementStatistics,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load resident statistics');
    }
  }

  /// Process move-out for a resident.
  Future<Map<String, dynamic>> moveOut({
    required String residentId,
    required String villaId,
    String? reason,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.residentManagementMoveOut,
        data: {
          'residentId': residentId,
          'villaId': villaId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to process move-out');
    }
  }

  /// Reactivate an inactive resident.
  Future<Map<String, dynamic>> reactivate(String residentId) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.residentManagementReactivate(residentId),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to reactivate resident');
    }
  }
}
