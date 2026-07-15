import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// L2 — consent & terms versioning.
///
/// Snapshot of the current legal versions and whether the signed-in user must
/// (re-)accept them. Mirrors the backend `GET /api/legal/status` shape.
class LegalConsentStatus {
  const LegalConsentStatus({
    required this.currentTermsVersion,
    required this.currentPrivacyVersion,
    required this.requiresAcceptance,
    this.acceptedTermsVersion,
    this.acceptedPrivacyVersion,
    this.termsUrl,
    this.privacyUrl,
  });

  final String currentTermsVersion;
  final String currentPrivacyVersion;
  final bool requiresAcceptance;
  final String? acceptedTermsVersion;
  final String? acceptedPrivacyVersion;
  final String? termsUrl;
  final String? privacyUrl;

  factory LegalConsentStatus.fromJson(Map<String, dynamic> json) {
    return LegalConsentStatus(
      currentTermsVersion: (json['currentTermsVersion'] ?? '').toString(),
      currentPrivacyVersion: (json['currentPrivacyVersion'] ?? '').toString(),
      requiresAcceptance: json['requiresAcceptance'] == true,
      acceptedTermsVersion: json['acceptedTermsVersion']?.toString(),
      acceptedPrivacyVersion: json['acceptedPrivacyVersion']?.toString(),
      termsUrl: json['termsUrl']?.toString(),
      privacyUrl: json['privacyUrl']?.toString(),
    );
  }
}

class LegalRepository {
  Dio get _dio => DioClient.dio;

  /// Current versions + this user's acceptance state.
  Future<LegalConsentStatus> getStatus() async {
    final response = await _dio.get(ApiEndpoints.legalStatus);
    final data = Map<String, dynamic>.from(response.data as Map);
    return LegalConsentStatus.fromJson(data);
  }

  /// Record acceptance of the current versions. The backend rejects (409) if the
  /// submitted versions are stale, so we always echo the server's current versions.
  Future<LegalConsentStatus> accept({
    required String termsVersion,
    required String privacyVersion,
    String? appVersion,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.legalAccept,
      data: {
        'termsVersion': termsVersion,
        'privacyVersion': privacyVersion,
        if (appVersion != null && appVersion.isNotEmpty) 'appVersion': appVersion,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return LegalConsentStatus.fromJson(data);
  }
}
