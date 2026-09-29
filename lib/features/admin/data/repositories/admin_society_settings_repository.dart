import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminSocietySettingsRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch society settings (gate rules, visitor approval mode, etc.).
  /// The backend returns `{ society: { ... } }` — unwrap to flat map.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.societySettings,
      );
      final body = res.data ?? {};
      // Unwrap nested `society` key so callers can read fields directly.
      if (body['society'] is Map<String, dynamic>) {
        return body['society'] as Map<String, dynamic>;
      }
      return body;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load society settings');
    }
  }

  /// Update society settings.
  Future<Map<String, dynamic>> updateSettings({
    String? visitorMultiVillaApprovalMode,
    bool? visitorApprovalRequired,
    bool? guardCanApproveVisitors,
    String? upiVpa,
    bool clearUpiVpa = false,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.societySettings,
        data: {
          if (visitorMultiVillaApprovalMode != null)
            'visitorMultiVillaApprovalMode': visitorMultiVillaApprovalMode,
          if (visitorApprovalRequired != null)
            'visitorApprovalRequired': visitorApprovalRequired,
          if (guardCanApproveVisitors != null)
            'guardCanApproveVisitors': guardCanApproveVisitors,
          if (clearUpiVpa)
            'upiVpa': null
          else if (upiVpa != null)
            'upiVpa': upiVpa,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update society settings');
    }
  }

  Future<void> updateLateFee({
    required double lateFeePercentage,
    required double lateFeeFixedAmount,
    required int gracePeriodDays,
  }) async {
    try {
      await _dio.patch(
        '${ApiEndpoints.societySettings}/late-fee',
        data: {
          'lateFeePercentage': lateFeePercentage,
          'lateFeeFixedAmount': lateFeeFixedAmount,
          'maintenanceGracePeriodDays': gracePeriodDays,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to save late fee settings');
    }
  }

  /// [mode] is FIXED or SQFT. Amounts must be positive.
  Future<void> updateMaintenanceBilling({
    required String mode,
    required double fixedAmount,
    required double sqftRate,
    required bool useChargeHeads,
  }) async {
    try {
      await _dio.patch(
        '${ApiEndpoints.societySettings}/maintenance-billing',
        data: {
          'maintenanceBillingMode': mode,
          'maintenanceFixedAmount': fixedAmount,
          'maintenanceSqftRate': sqftRate,
          'useChargeHeads': useChargeHeads,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to save billing mode');
    }
  }

  Future<List<Map<String, dynamic>>> getChargeHeads() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.societySettings}/charge-heads',
      );
      final list = res.data?['chargeHeads'];
      return list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load charge heads');
    }
  }

  /// [amountType] is FIXED (uses [fixedAmount]) or PER_SQFT (uses [perSqftRate]).
  Future<void> addChargeHead({
    required String code,
    required String label,
    required String amountType,
    double? fixedAmount,
    double? perSqftRate,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.societySettings}/charge-heads',
        data: {
          'code': code,
          'label': label,
          'amountType': amountType,
          if (amountType == 'FIXED') 'fixedAmount': fixedAmount,
          if (amountType == 'PER_SQFT') 'perSqftRate': perSqftRate,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to add charge head');
    }
  }

  Future<void> removeChargeHead(String id) async {
    try {
      await _dio.delete('${ApiEndpoints.societySettings}/charge-heads/$id');
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to remove charge head');
    }
  }

  /// [kind] is one of qr, letterhead, signature, stamp, splash.
  Future<void> uploadBrandingImage(
    String kind,
    Uint8List bytes,
    String filename,
  ) async {
    final spec = _brandingSpecs[kind]!;
    final lower = filename.toLowerCase();
    final subtype = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
            ? 'webp'
            : 'jpeg';
    try {
      await _dio.post(
        '${ApiEndpoints.societySettings}/${spec.uploadPath}',
        data: FormData.fromMap({
          spec.field: MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType('image', subtype),
          ),
        }),
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Upload failed');
    }
  }

  Future<void> removeBrandingImage(String kind) async {
    try {
      await _dio.delete(
        '${ApiEndpoints.societySettings}/${_brandingSpecs[kind]!.removePath}',
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not remove image');
    }
  }

  static const _brandingSpecs = <String, _BrandingSpec>{
    'qr': _BrandingSpec('qrImage', 'upload-qr', 'qr-code'),
    'letterhead': _BrandingSpec('letterhead', 'upload-letterhead', 'letterhead'),
    'signature': _BrandingSpec('signature', 'upload-signature', 'signature'),
    'stamp': _BrandingSpec('stamp', 'upload-stamp', 'stamp'),
    'splash': _BrandingSpec('splash', 'upload-splash', 'splash'),
  };
}

class _BrandingSpec {
  const _BrandingSpec(this.field, this.uploadPath, this.removePath);

  final String field;
  final String uploadPath;
  final String removePath;
}
