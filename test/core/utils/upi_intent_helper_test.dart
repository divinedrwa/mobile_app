import 'package:flutter_test/flutter_test.dart';
import 'package:divine_app/core/utils/upi_intent_helper.dart';

void main() {
  group('UpiIntentHelper.buildPaymentIntent', () {
    test('rebuilds an unsigned merchant QR as a spec-correct P2M intent', () {
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

      // pa decoded (literal @) — some apps reject %40 as an invalid VPA.
      expect(intent, contains('pa=bom260601340945@mahb'));
      // pn decoded from '+' form-encoding and re-encoded as %20.
      expect(intent, contains('pn=DIVINE%20RESIDENCY%20WEL'));
      // mc/purpose kept → stays person-to-merchant (P2M), dodging NPCI's
      // per-payee 24h cap that a bare P2P intent hits.
      expect(intent, contains('mc=2741'));
      expect(intent, contains('purpose=00'));
      // Intent channel, not the QR's scan-channel value.
      expect(intent, contains('mode=04'));
      expect(intent, isNot(contains('mode=01')));
      // Unique transaction reference — required for merchant intents.
      expect(intent, matches(RegExp(r'(\?|&)tr=MNT[A-Z0-9]+(&|$)')));
      expect(intent, contains('am=1500.00'));
      // stale cu replaced, not duplicated
      expect('cu='.allMatches(intent).length, 1);
      expect(intent, contains('tn=Maintenance%206-2026'));
    });

    test('replays a signed merchant QR verbatim, setting only am/cu/tn', () {
      const sign = 'abc+def/ghi==';
      const qr =
          'upi://pay?pa=divine%40mahb&pn=DIVINE&mc=5411&mode=01&orgid=159761&sign=$sign';

      final intent = UpiIntentHelper.buildPaymentIntent(
        vpa: 'divine@mahb',
        payeeName: 'DIVINE',
        amount: 1500,
        remark: 'Maintenance 6/2026',
        upiPayUri: qr,
      );

      // Signature covers the payload — everything byte-for-byte, including
      // the encoded pa and the base64 sign.
      expect(intent, contains('pa=divine%40mahb'));
      expect(intent, contains('mode=01'));
      expect(intent, contains('sign=$sign'));
      expect(intent, isNot(contains('tr=')));
      expect(intent, contains('am=1500.00'));
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
