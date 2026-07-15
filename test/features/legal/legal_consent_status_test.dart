import 'package:flutter_test/flutter_test.dart';
import 'package:divine_app/features/legal/data/legal_repository.dart';

void main() {
  group('LegalConsentStatus.fromJson', () {
    test('parses a "must re-accept" status with null accepted versions', () {
      final status = LegalConsentStatus.fromJson({
        'currentTermsVersion': '2026-07-07',
        'currentPrivacyVersion': '2026-07-07',
        'acceptedTermsVersion': null,
        'acceptedPrivacyVersion': null,
        'acceptedAt': null,
        'requiresAcceptance': true,
        'termsUrl': null,
        'privacyUrl': null,
      });

      expect(status.requiresAcceptance, isTrue);
      expect(status.currentTermsVersion, '2026-07-07');
      expect(status.acceptedTermsVersion, isNull);
      expect(status.termsUrl, isNull);
    });

    test('parses an up-to-date status with hosted URLs', () {
      final status = LegalConsentStatus.fromJson({
        'currentTermsVersion': '2026-07-07',
        'currentPrivacyVersion': '2026-07-07',
        'acceptedTermsVersion': '2026-07-07',
        'acceptedPrivacyVersion': '2026-07-07',
        'requiresAcceptance': false,
        'termsUrl': 'https://example.com/terms',
        'privacyUrl': 'https://example.com/privacy',
      });

      expect(status.requiresAcceptance, isFalse);
      expect(status.acceptedPrivacyVersion, '2026-07-07');
      expect(status.termsUrl, 'https://example.com/terms');
    });

    test('treats a missing/non-true requiresAcceptance as false', () {
      final status = LegalConsentStatus.fromJson({
        'currentTermsVersion': '2026-07-07',
        'currentPrivacyVersion': '2026-07-07',
      });

      expect(status.requiresAcceptance, isFalse);
      expect(status.acceptedTermsVersion, isNull);
    });
  });
}
