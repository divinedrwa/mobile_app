import 'package:dio/dio.dart';
import '../errors/exceptions.dart';
import 'api_error_message.dart';

/// Maps a [DioException] to an [AppException], preserving the instance from
/// [ErrorInterceptor] when present so Zod `issues` are not lost.
AppException mapDioException(DioException e, String fallbackMessage) {
  final inner = e.error;
  if (inner is AppException) {
    return inner;
  }

  // Handle rate limiting (HTTP 429)
  if (e.response?.statusCode == 429) {
    final retryAfterHeader = e.response?.headers.value('retry-after');
    final retryAfter = int.tryParse(retryAfterHeader ?? '60') ?? 60;
    return RateLimitException(
      message: parseApiErrorMessage(
        e.response?.data,
        'Too many requests. Please wait $retryAfter seconds and try again.',
      ),
      retryAfter: retryAfter,
    );
  }

  return ServerException(
    message: parseApiErrorMessage(e.response?.data, fallbackMessage),
    data: e.response?.data is Map ? e.response?.data : null,
    statusCode: e.response?.statusCode,
  );
}

/// Snackbar / dialog text from any thrown error.
String userFacingMessage(Object error, [String fallback = 'Something went wrong']) {
  if (error is AppException) return error.message;
  if (error is DioException) return mapDioException(error, fallback).message;
  return error.toString();
}
