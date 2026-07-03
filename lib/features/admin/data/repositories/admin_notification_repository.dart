import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminNotificationRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminNotificationsDiagnostics,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load notification diagnostics');
    }
  }

  Future<Map<String, dynamic>> broadcast({
    required String title,
    required String body,
    required List<String> targetRoles,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminNotificationsBroadcast,
        data: {
          'title': title,
          'body': body,
          'targetRoles': targetRoles,
          'category': 'BROADCAST',
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send broadcast');
    }
  }

  Future<Map<String, dynamic>> sendTest() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminNotificationsSendTest,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send test notification');
    }
  }
}
