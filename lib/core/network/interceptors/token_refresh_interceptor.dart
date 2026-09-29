import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../utils/storage_service.dart';
import '../dio_client.dart';
import '../session_refresher.dart';
import 'error_interceptor.dart' show isAuthExemptPath;

/// Intercepts 401 responses, refreshes the session once, and retries.
///
/// All refreshes go through [SessionRefresher], so concurrent 401s (and the
/// refresh at app start) share one `/auth/refresh` call instead of racing
/// each other with the same rotating refresh token.
class TokenRefreshInterceptor extends QueuedInterceptor {
  /// Set only when the server explicitly rejected the refresh token, so the
  /// burst of 401s that follows doesn't retry a dead session.
  DateTime? _lastRefreshRejectedAt;

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

  Future<void> _retryWith(
    String token,
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    opts.headers['Authorization'] = 'Bearer $token';
    try {
      final retryResponse = await _makeFreshDio().fetch(opts);
      handler.resolve(retryResponse);
    } on DioException catch (retryErr) {
      // Forward the retry's own error; a 401 here means the new token is also
      // refused (e.g. account removed), which is a real session end.
      handler.next(retryErr);
    } catch (_) {
      handler.next(err);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        isAuthExemptPath(err.requestOptions.path)) {
      return handler.next(err);
    }

    // The request went out with a token that has since been replaced (another
    // request or app start refreshed it) — retry with the current one.
    final stored = await StorageService.getToken();
    final sentAuth = err.requestOptions.headers['Authorization']?.toString();
    if (stored != null && stored.isNotEmpty && sentAuth != 'Bearer $stored') {
      return _retryWith(stored, err, handler);
    }

    if (_lastRefreshRejectedAt != null &&
        DateTime.now().difference(_lastRefreshRejectedAt!) <
            const Duration(seconds: 10)) {
      return handler.next(err);
    }

    final result = await SessionRefresher.refresh();
    switch (result.status) {
      case SessionRefreshStatus.success:
        _lastRefreshRejectedAt = null;
        final token = await StorageService.getToken();
        if (token == null || token.isEmpty) {
          return handler.next(err);
        }
        if (kDebugMode) debugPrint('[TokenRefresh] session refreshed, retrying');
        return _retryWith(token, err, handler);
      case SessionRefreshStatus.rejected:
        _lastRefreshRejectedAt = DateTime.now();
        if (kDebugMode) debugPrint('[TokenRefresh] refresh token rejected by server');
        return handler.next(err);
      case SessionRefreshStatus.transient:
        // Keep the session: surface a connection error so ErrorInterceptor
        // does not treat this 401 as a session expiry.
        if (kDebugMode) debugPrint('[TokenRefresh] refresh failed (transient), keeping session');
        return handler.next(DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.connectionError,
          error: 'Token refresh failed (network)',
          message: 'Could not refresh session — please check your connection',
        ));
    }
  }
}
