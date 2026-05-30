import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../constants/api_endpoints.dart';
import '../../utils/storage_service.dart';
import '../dio_client.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart' show isAuthExemptPath;

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

  /// Timestamp of the most recent *rejected* refresh (server returned 401/403
  /// on the refresh endpoint itself). Only set when the server explicitly says
  /// the refresh token is invalid — NOT on transient network errors.
  DateTime? _lastRefreshFailedAt;

  Dio _makeFreshDio() {
    final parentOpts = DioClient.dio.options;
    return Dio(BaseOptions(
      baseUrl: parentOpts.baseUrl,
      connectTimeout: parentOpts.connectTimeout,
      receiveTimeout: parentOpts.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        isAuthExemptPath(err.requestOptions.path)) {
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

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        // Malformed response — server bug, not token rejection. Treat as
        // transient so the user stays logged in.
        return handler.next(DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.connectionError,
          error: 'Malformed refresh response',
          message: 'Could not refresh session',
        ));
      }
      final newAccessToken = data['token'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken == null || newRefreshToken == null) {
        // Missing fields — same as above, treat as transient.
        return handler.next(DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.connectionError,
          error: 'Incomplete refresh response',
          message: 'Could not refresh session',
        ));
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
    } on DioException catch (refreshErr) {
      final status = refreshErr.response?.statusCode;
      if (status == 401 || status == 403) {
        // Server explicitly rejected the refresh token — session is dead.
        _lastRefreshFailedAt = DateTime.now();
        if (kDebugMode) {
          debugPrint('[TokenRefresh] refresh rejected by server ($status)');
        }
        return handler.next(err);
      }
      // Network / timeout / 5xx — transient failure. Don't mark the session
      // as dead; convert the original 401 to a connection error so
      // ErrorInterceptor does NOT trigger SessionExpiredHandler.
      if (kDebugMode) {
        debugPrint('[TokenRefresh] refresh failed (network/transient), '
            'keeping session alive');
      }
      return handler.next(DioException(
        requestOptions: err.requestOptions,
        type: DioExceptionType.connectionError,
        error: refreshErr.error ?? 'Token refresh failed (network)',
        message: 'Could not refresh session — please check your connection',
      ));
    } catch (e) {
      // Unexpected non-Dio error — treat as transient, keep session alive.
      if (kDebugMode) {
        debugPrint('[TokenRefresh] unexpected error during refresh: $e');
      }
      return handler.next(DioException(
        requestOptions: err.requestOptions,
        type: DioExceptionType.connectionError,
        error: e,
        message: 'Could not refresh session',
      ));
    }
  }
}
