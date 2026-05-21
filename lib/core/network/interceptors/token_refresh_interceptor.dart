import 'dart:async';

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
/// that hit 401 at the same time share a single refresh call.
class TokenRefreshInterceptor extends QueuedInterceptor {
  bool _isRefreshing = false;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        _isRefreshExempt(err.requestOptions.path)) {
      return handler.next(err);
    }

    // Prevent re-entrant refresh
    if (_isRefreshing) {
      return handler.next(err);
    }

    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      // Use a fresh Dio instance to avoid interceptor loops.
      final freshDio = Dio(BaseOptions(
        baseUrl: DioClient.dio.options.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await freshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['token'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken == null || newRefreshToken == null) {
        return handler.next(err);
      }

      // Persist new tokens
      await StorageService.saveToken(newAccessToken);
      await StorageService.saveRefreshToken(newRefreshToken);
      AuthInterceptor.clearCache();

      if (kDebugMode) {
        debugPrint('[TokenRefresh] tokens refreshed successfully');
      }

      // Retry the original request with the new access token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await freshDio.fetch(opts);
      return handler.resolve(retryResponse);
    } on DioException {
      // Refresh failed — let the original 401 propagate so
      // ErrorInterceptor triggers SessionExpiredHandler.
      return handler.next(err);
    } catch (_) {
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
