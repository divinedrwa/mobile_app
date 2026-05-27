import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminSosRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch SOS alerts with optional status filter.
  Future<Map<String, dynamic>> getSosAlerts({String? status}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminSosAlerts,
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load SOS alerts');
    }
  }

  /// Get all active SOS alerts.
  Future<List<Map<String, dynamic>>> getActiveSosAlerts() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminSosAlertsActive,
      );
      final list = res.data?['alerts'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load active SOS alerts');
    }
  }

  /// Get SOS stats (admin only).
  Future<Map<String, dynamic>> getSosStats() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminSosAlertsStats,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load SOS stats');
    }
  }

  /// Acknowledge an SOS alert.
  Future<void> acknowledgeSos(String id) async {
    try {
      await _dio.patch(ApiEndpoints.adminSosAcknowledge(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to acknowledge SOS');
    }
  }

  /// Start responding to an SOS alert.
  Future<void> startSos(String id) async {
    try {
      await _dio.patch(ApiEndpoints.adminSosStart(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to start SOS response');
    }
  }

  /// Resolve an SOS alert.
  Future<void> resolveSos(String id) async {
    try {
      await _dio.patch(ApiEndpoints.adminSosResolve(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to resolve SOS');
    }
  }
}
