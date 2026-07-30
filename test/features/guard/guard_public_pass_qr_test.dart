import 'package:divine_app/features/guard/data/guard_public_pass_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public visitor pass QR', () {
    final token = List.filled(43, 'a').join();

    test('accepts only an HTTPS /visit token URL', () {
      expect(
        parseVisitorPublicPassToken('https://admin.example.com/visit/$token'),
        token,
      );
      expect(
        parseVisitorPublicPassToken('http://admin.example.com/visit/$token'),
        isNull,
      );
      expect(
        parseVisitorPublicPassToken('https://admin.example.com/other/$token'),
        isNull,
      );
      expect(parseVisitorPublicPassToken('123456'), isNull);
    });

    test('maps an authenticated resolve response to approval fields', () {
      expect(
        guardPayloadFromResolvedPublicPass({
          'verified': true,
          'otp': '123456',
          'preApproved': {
            'name': 'Driver',
            'phone': '9876543210',
            'villaId': 'villa-1',
          },
        }),
        {
          'otp': '123456',
          'name': 'Driver',
          'phone': '9876543210',
          'villaId': 'villa-1',
        },
      );
    });

    test('rejects failed or malformed resolve responses', () {
      expect(guardPayloadFromResolvedPublicPass({'verified': false}), isNull);
      expect(
        guardPayloadFromResolvedPublicPass({
          'verified': true,
          'preApproved': {'villaId': 'villa-1'},
        }),
        isNull,
      );
    });
  });
}
