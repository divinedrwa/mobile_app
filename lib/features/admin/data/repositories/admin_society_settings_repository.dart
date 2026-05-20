import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminSocietySettingsRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch society settings (gate rules, visitor approval mode, etc.).
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.societySettings,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load society settings');
    }
  }

  /// Update society settings.
  Future<Map<String, dynamic>> updateSettings({
    String? visitorMultiVillaApprovalMode,
    bool? visitorApprovalRequired,
    bool? guardCanApproveVisitors,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.societySettings,
        data: {
          if (visitorMultiVillaApprovalMode != null)
            'visitorMultiVillaApprovalMode': visitorMultiVillaApprovalMode,
          if (visitorApprovalRequired != null)
            'visitorApprovalRequired': visitorApprovalRequired,
          if (guardCanApproveVisitors != null)
            'guardCanApproveVisitors': guardCanApproveVisitors,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update society settings');
    }
  }
}
