import 'package:dio/dio.dart';
import '../../utils/storage_service.dart';

/// Adds the bearer JWT to outbound requests. Reads from [StorageService]
/// (secure storage on device) — never from SharedPreferences directly.
///
/// The token is cached in memory after the first read so subsequent requests
/// skip the async storage lookup. Call [clearCache] on logout or token refresh.
class AuthInterceptor extends Interceptor {
  static String? _cachedToken;

  /// Clears the in-memory token cache. Call on logout or when the token changes.
  static void clearCache() {
    _cachedToken = null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    String? token = _cachedToken;
    if (token == null) {
      token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
      }
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
