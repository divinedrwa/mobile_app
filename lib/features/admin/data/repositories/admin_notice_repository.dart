import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminNoticeRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all society notices.
  Future<Map<String, dynamic>> getAdminNotices() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminNotices,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load notices');
    }
  }

  /// Create a new notice.
  Future<Map<String, dynamic>> createNotice({
    required String title,
    required String content,
    String? category,
    String? priority,
    bool isUrgent = false,
    bool notifyResidents = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminNotices,
        data: {
          'title': title,
          'content': content,
          if (category != null) 'category': category,
          if (priority != null) 'priority': priority,
          'isUrgent': isUrgent,
          'notifyResidents': notifyResidents,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create notice');
    }
  }

  /// Delete a notice.
  Future<void> deleteNotice(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminNoticeById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete notice');
    }
  }
}
