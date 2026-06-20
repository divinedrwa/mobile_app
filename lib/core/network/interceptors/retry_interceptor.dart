import 'dart:async';
import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Retries failed requests on transient server errors (502, 503, 504) and
/// rate limiting (429) with exponential backoff. Only GET requests are retried
/// for 5xx and 429 errors — mutating methods are left alone to avoid duplicate
/// side effects (payments, check-ins, etc.).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxRetries = 2});

  final int maxRetries;

  static const _retriableStatuses = {502, 503, 504};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final isGet = err.requestOptions.method.toUpperCase() == 'GET';

    // Handle rate limiting (429) — GET only; never auto-retry POST/PATCH/DELETE
    if (statusCode == 429) {
      if (!isGet) {
        return handler.next(err);
      }

      final attempt = (err.requestOptions.extra['_retryAttempt'] as int?) ?? 0;
      if (attempt >= 1) {
        // Only retry once for rate limiting to avoid prolonged delays
        return handler.next(err);
      }

      // Read Retry-After header from server (in seconds)
      final retryAfterHeader = err.response?.headers.value('retry-after');
      final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '60') ?? 60;
      // Cap at 2 minutes for UX reasons
      final delayMs = min(retryAfterSeconds * 1000, 120000);

      if (kDebugMode) {
        debugPrint('[RetryInterceptor] 429 Rate Limited on ${err.requestOptions.path} '
            '— retrying once in ${delayMs}ms');
      }

      await Future<void>.delayed(Duration(milliseconds: delayMs));

      try {
        err.requestOptions.extra['_retryAttempt'] = attempt + 1;
        final dio = Dio()..options.baseUrl = err.requestOptions.baseUrl;
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    // Handle transient server errors (502, 503, 504) - GET only
    final isTimeout = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;
    if (!isGet || (!isTimeout && (statusCode == null || !_retriableStatuses.contains(statusCode)))) {
      return handler.next(err);
    }

    final attempt = (err.requestOptions.extra['_retryAttempt'] as int?) ?? 0;
    if (attempt >= maxRetries) {
      return handler.next(err);
    }

    final delayMs = min(1000 * (1 << attempt), 4000); // 1s, 2s, 4s
    if (kDebugMode) {
      final reason = isTimeout ? 'timeout(${err.type.name})' : '$statusCode';
      debugPrint('[RetryInterceptor] $reason on ${err.requestOptions.path} '
          '— retry ${attempt + 1}/$maxRetries in ${delayMs}ms');
    }

    await Future<void>.delayed(Duration(milliseconds: delayMs));

    try {
      err.requestOptions.extra['_retryAttempt'] = attempt + 1;
      final dio = Dio()..options.baseUrl = err.requestOptions.baseUrl;
      final response = await dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
