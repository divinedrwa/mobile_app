import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminSocietySettingsRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch society settings (gate rules, visitor approval mode, etc.).
  /// The backend returns `{ society: { ... } }` — unwrap to flat map.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.societySettings,
      );
      final body = res.data ?? {};
      // Unwrap nested `society` key so callers can read fields directly.
      if (body['society'] is Map<String, dynamic>) {
        return body['society'] as Map<String, dynamic>;
      }
      return body;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load society settings');
    }
  }

  /// Update society settings.
  Future<Map<String, dynamic>> updateSettings({
    String? visitorMultiVillaApprovalMode,
    bool? visitorApprovalRequired,
    bool? guardCanApproveVisitors,
    String? upiVpa,
    bool clearUpiVpa = false,
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
          if (clearUpiVpa)
            'upiVpa': null
          else if (upiVpa != null)
            'upiVpa': upiVpa,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update society settings');
    }
  }
}
