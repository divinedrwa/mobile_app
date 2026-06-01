import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../errors/exceptions.dart';
import '../../session/account_deactivated_handler.dart';
import '../../session/session_expired_handler.dart';
import '../api_error_message.dart';

bool _accountDisabledMessage(String message) {
  final s = message.toLowerCase().trim();
  if (s.contains('deactivated')) return true;
  if (s.contains('account is inactive')) return true;
  if (s.contains('inactive') && s.contains('account')) return true;
  return false;
}

/// Endpoints where a 401 must NOT trigger the session-expired flow or token
/// refresh. Shared between [ErrorInterceptor] and [TokenRefreshInterceptor].
///
/// • `/auth/login`, `/auth/register-with-invitation` — a 401 here means
///   "bad credentials / invalid invitation", not "session expired".
/// • `/auth/logout`, `/notifications/devices/remove` — teardown calls made
///   during logout. The JWT may already be revoked.
bool isAuthExemptPath(String path) {
  final p = path.toLowerCase();
  return p.endsWith('/auth/login') ||
      p.endsWith('/auth/register-with-invitation') ||
      p.endsWith('/auth/logout') ||
      p.endsWith('/auth/refresh') ||
      p.endsWith('/notifications/devices/remove') ||
      p.endsWith('/notifications/devices');
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
        // On web, CORS failures surface as connection errors (XMLHttpRequest
        // error). "No internet" is misleading — the browser is online but the
        // server rejected the cross-origin request or is unreachable.
        exception = NetworkException(
          message: kIsWeb
              ? 'Cannot reach server. Check the API URL or try again.'
              : 'No internet connection',
        );
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
            } else if (!isAuthExemptPath(
              err.requestOptions.path,
            )) {
              // Generic 401 on an authenticated endpoint = token expired /
              // revoked / signing-key rotated. Force a single logout +
              // redirect; the SessionExpiredHandler guards against multiple
              // parallel requests each firing.
              //
              // A 401 from `/auth/login` itself is *not* a session expiry —
              // it's "wrong username or password" and must surface inline on
              // the login form without clearing storage or navigating away.
              unawaited(SessionExpiredHandler.triggerIfRegistered());
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
