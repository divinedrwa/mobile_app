import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminReconciliationRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getSummary() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.reconciliationSummary,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load reconciliation summary');
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts({String? status}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.reconciliationAlerts,
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['alerts'] is List) {
        return (data['alerts'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load reconciliation alerts');
    }
  }

  Future<Map<String, dynamic>> resolveAlert(
    String id, {
    String? notes,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.reconciliationAlertResolve(id),
        data: {
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to resolve alert');
    }
  }
}
