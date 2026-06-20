import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminComplaintRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch society complaints with optional status filter.
  Future<Map<String, dynamic>> getAdminComplaints({
    int limit = 200,
    int offset = 0,
    String? status,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminComplaints,
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (status != null) 'status': status,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load complaints');
    }
  }

  /// Fetch 30-day complaint analytics summary.
  Future<Map<String, dynamic>> getComplaintAnalyticsSummary({
    int days = 30,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.complaintAnalyticsSummary,
        queryParameters: {'days': days},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load complaint analytics');
    }
  }

  /// Update complaint status with optional admin notes.
  Future<Map<String, dynamic>> updateComplaintStatus(
    String id, {
    required String status,
    String? adminNotes,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.complaintAnalyticsQuickUpdate(id),
        data: {
          'status': status,
          if (adminNotes != null && adminNotes.isNotEmpty)
            'adminNotes': adminNotes,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update complaint status');
    }
  }
}
