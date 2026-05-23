import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../constants/api_endpoints.dart';
import '../../utils/storage_service.dart';
import '../dio_client.dart';
import 'auth_interceptor.dart';

/// Endpoints that should never trigger a token refresh attempt.
bool _isRefreshExempt(String path) {
  final p = path.toLowerCase();
  return p.endsWith('/auth/login') ||
      p.endsWith('/auth/register-with-invitation') ||
      p.endsWith('/auth/logout') ||
      p.endsWith('/auth/refresh') ||
      p.endsWith('/notifications/devices/remove') ||
      p.endsWith('/notifications/devices');
}

/// Intercepts 401 responses and attempts a single token refresh before
/// forwarding the error. Uses [QueuedInterceptor] so concurrent requests
/// that hit 401 at the same time are serialised — only the first one
/// actually calls `/auth/refresh`; subsequent ones just retry with the
/// already-refreshed token.
class TokenRefreshInterceptor extends QueuedInterceptor {
  /// Timestamp of the most recent successful token refresh. Concurrent 401s
  /// that arrive after a recent refresh skip the refresh call and just retry
  /// with the already-stored token.
  DateTime? _lastRefreshAt;

  /// Timestamp of the most recent *failed* refresh. Once a refresh fails the
  /// session is dead — subsequent queued 401s should not retry the refresh
  /// and should just propagate the 401 immediately.
  DateTime? _lastRefreshFailedAt;

  Dio _makeFreshDio() => Dio(BaseOptions(
        baseUrl: DioClient.dio.options.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        _isRefreshExempt(err.requestOptions.path)) {
      return handler.next(err);
    }

    // If a refresh recently failed, the session is dead. Don't attempt
    // another refresh — just let the 401 propagate immediately.
    if (_lastRefreshFailedAt != null &&
        DateTime.now().difference(_lastRefreshFailedAt!) <
            const Duration(seconds: 10)) {
      if (kDebugMode) {
        debugPrint('[TokenRefresh] skipping — refresh failed recently, '
            'letting 401 propagate');
      }
      return handler.next(err);
    }

    // If tokens were refreshed very recently (by a preceding queued 401),
    // skip the refresh call and just retry with the stored token.
    if (_lastRefreshAt != null &&
        DateTime.now().difference(_lastRefreshAt!) <
            const Duration(seconds: 5)) {
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[TokenRefresh] skipping refresh — tokens refreshed '
              '${DateTime.now().difference(_lastRefreshAt!).inMilliseconds}ms ago, retrying');
        }
        try {
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          final retryResponse = await _makeFreshDio().fetch(opts);
          return handler.resolve(retryResponse);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        } catch (_) {
          return handler.next(err);
        }
      }
    }

    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return handler.next(err);
    }

    try {
      final freshDio = _makeFreshDio();

      final response = await freshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['token'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken == null || newRefreshToken == null) {
        _lastRefreshFailedAt = DateTime.now();
        return handler.next(err);
      }

      // Persist new tokens
      await StorageService.saveToken(newAccessToken);
      await StorageService.saveRefreshToken(newRefreshToken);
      AuthInterceptor.clearCache();
      _lastRefreshAt = DateTime.now();
      _lastRefreshFailedAt = null; // clear any prior failure

      if (kDebugMode) {
        debugPrint('[TokenRefresh] tokens refreshed successfully');
      }

      // Retry the original request with the new access token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccessToken';

      try {
        final retryResponse = await freshDio.fetch(opts);
        return handler.resolve(retryResponse);
      } on DioException catch (retryErr) {
        // Refresh succeeded but the retry itself failed (timeout, 500, etc.).
        // The session is still valid — propagate the RETRY error, not the
        // original 401, so ErrorInterceptor does NOT trigger logout.
        if (kDebugMode) {
          debugPrint('[TokenRefresh] retry failed after successful refresh '
              '(${retryErr.response?.statusCode}), forwarding retry error');
        }
        return handler.next(retryErr);
      }
    } on DioException {
      // Refresh itself failed — the session truly expired.
      _lastRefreshFailedAt = DateTime.now();
      return handler.next(err);
    } catch (_) {
      _lastRefreshFailedAt = DateTime.now();
      return handler.next(err);
    }
  }
}
