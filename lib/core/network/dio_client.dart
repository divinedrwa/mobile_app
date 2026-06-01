import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/app_constants.dart';
import 'dio_cert_pinning.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/society_context_interceptor.dart';
import 'interceptors/token_refresh_interceptor.dart';

/// Dio HTTP client configuration
class DioClient {
  static Dio? _dio;

  static Dio get dio {
    if (_dio != null) return _dio!;

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors. Logger only in debug — release builds must not write
    // JWTs, request bodies, or PII to device logs.
    _dio!.interceptors.addAll([
      SocietyContextInterceptor(),
      AuthInterceptor(),
      RetryInterceptor(),
      TokenRefreshInterceptor(),
      ErrorInterceptor(),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
    ]);

    // Certificate pinning — activates when CertificatePins.enabled is true
    // and at least one SPKI SHA-256 pin is configured. No-op on web.
    configureCertPinning(_dio!);

    return _dio!;
  }

  /// Discards the current client [after logout or API base URL change].
  /// Do not cache [dio] in long-lived objects — always read [dio] when making a request.
  static void reset() {
    _dio?.close();
    _dio = null;
    AuthInterceptor.clearCache();
    SocietyContextInterceptor.clearCache();
  }

  /// GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
