import 'package:flutter_test/flutter_test.dart';
import 'package:divine_app/core/utils/upi_intent_helper.dart';

void main() {
  group('UpiIntentHelper.buildPaymentIntent', () {
    test('replays a real merchant QR verbatim and adds only am/cu/tn', () {
      // Exact shape of the society's Bank of Maharashtra merchant QR:
      // encoded @ (%40) in pa, mc present, no signature, variable amount.
      const qr =
          'upi://pay?pa=bom260601340945%40mahb&pn=DIVINE+RESIDENCY+WEL&cu=INR&mc=2741&mode=01&purpose=00';

      final intent = UpiIntentHelper.buildPaymentIntent(
        vpa: 'bom260601340945@mahb',
        payeeName: 'DIVINE RESIDENCY WEL',
        amount: 1500,
        remark: 'Maintenance 6/2026',
        upiPayUri: qr,
      );

      // Merchant identity kept byte-for-byte → stays person-to-merchant (P2M),
      // dodging NPCI's per-payee 24h cap that a bare P2P intent hits.
      expect(intent, contains('pa=bom260601340945%40mahb'));
      expect(intent, contains('mc=2741'));
      expect(intent, contains('mode=01'));
      expect(intent, contains('purpose=00'));
      expect(intent, contains('am=1500.00'));
      // stale cu replaced, not duplicated
      expect('cu='.allMatches(intent).length, 1);
      expect(intent, contains('tn=Maintenance%206-2026'));
    });

    test('falls back to a plain P2P intent for a manual VPA (no signed URI)',
        () {
      final intent = UpiIntentHelper.buildPaymentIntent(
        vpa: 'someone@okhdfcbank',
        payeeName: 'Someone',
        amount: 250,
        remark: 'Maintenance 6/2026',
      );
      expect(intent, contains('pa=someone@okhdfcbank'));
      expect(intent, contains('am=250.00'));
      expect(intent, isNot(contains('mc=')));
    });
  });
}
