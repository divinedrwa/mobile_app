import 'dart:async';

import 'package:dio/dio.dart';
import '../../errors/exceptions.dart';
import '../../session/account_deactivated_handler.dart';
import '../api_error_message.dart';

bool _accountDisabledMessage(String message) {
  final s = message.toLowerCase().trim();
  if (s.contains('deactivated')) return true;
  if (s.contains('account is inactive')) return true;
  if (s.contains('inactive') && s.contains('account')) return true;
  return false;
}

/// Interceptor to handle API errors
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException exception;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        exception = NetworkException(message: 'Connection timeout');
        break;

      case DioExceptionType.connectionError:
        exception = NetworkException(message: 'No internet connection');
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final raw = err.response?.data;
        final message = parseApiErrorMessage(
          raw,
          raw is Map
              ? (raw['message'] as String? ??
                  raw['error'] as String? ??
                  'Something went wrong')
              : 'Something went wrong',
        );

        switch (statusCode) {
          case 400:
            exception = ValidationException(
              message: message,
              data: err.response?.data,
            );
            break;
          case 401:
            exception = UnauthorizedException(message: message);
            if (_accountDisabledMessage(message)) {
              unawaited(AccountDeactivatedHandler.triggerIfRegistered());
            }
            break;
          case 403:
            exception = ForbiddenException(message: message);
            if (_accountDisabledMessage(message)) {
              unawaited(AccountDeactivatedHandler.triggerIfRegistered());
            }
            break;
          case 404:
            exception = NotFoundException(message: message);
            break;
          case 500:
          case 502:
          case 503:
            exception = ServerException(
              message: message,
              data: raw is Map ? raw : null,
              statusCode: statusCode,
            );
            break;
          default:
            exception = AppException(
              message: message,
              statusCode: statusCode,
              data: err.response?.data,
            );
        }
        break;

      case DioExceptionType.cancel:
        exception = AppException(message: 'Request cancelled');
        break;

      case DioExceptionType.badCertificate:
        exception = AppException(message: 'Bad certificate');
        break;

      case DioExceptionType.unknown:
        exception = AppException(
          message: err.message ?? 'Unknown error occurred',
        );
        break;
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }
}
