import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminPaymentMethodRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminPaymentMethods);
      final data = res.data;
      if (data is Map) {
        final list = data['methods'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load payment methods');
    }
  }

  Future<Map<String, dynamic>> createPaymentMethod({
    required String type,
    required String displayName,
    required Map<String, dynamic> config,
    bool isEnabled = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminPaymentMethods,
        data: {
          'type': type,
          'displayName': displayName,
          'config': config,
          'isEnabled': isEnabled,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create payment method');
    }
  }

  Future<Map<String, dynamic>> updatePaymentMethod(
    String id, {
    String? displayName,
    bool? isEnabled,
    Map<String, dynamic>? config,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.adminPaymentMethodById(id),
        data: {
          if (displayName != null) 'displayName': displayName,
          if (isEnabled != null) 'isEnabled': isEnabled,
          if (config != null) 'config': config,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update payment method');
    }
  }

  Future<void> deletePaymentMethod(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminPaymentMethodById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete payment method');
    }
  }

  /// Uploads the bank's UPI QR image; the backend decodes and validates it.
  /// Returns the backend's `validation` block.
  Future<Map<String, dynamic>> uploadUpiQr(
    String id,
    Uint8List bytes,
    String filename,
  ) async {
    final lower = filename.toLowerCase();
    final subtype = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
            ? 'webp'
            : 'jpeg';
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminPaymentMethodUploadQr(id),
        data: FormData.fromMap({
          'qrImage': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType('image', subtype),
          ),
        }),
      );
      final validation = res.data?['validation'];
      return validation is Map ? Map<String, dynamic>.from(validation) : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not read the QR image');
    }
  }

  /// Validates the saved UPI ID. Returns the backend's `validation` block.
  Future<Map<String, dynamic>> verifyVpa(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminPaymentMethodVerifyVpa(id),
      );
      final validation = res.data?['validation'];
      return validation is Map ? Map<String, dynamic>.from(validation) : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'UPI ID verification failed');
    }
  }

  Future<Map<String, dynamic>> testConnection(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminPaymentMethodTest(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Connection test failed');
    }
  }
}
