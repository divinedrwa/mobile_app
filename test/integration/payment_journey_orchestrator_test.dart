import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/services/payment_orchestrator.dart';
import 'package:divine_app/features/resident/data/utils/gateway_payment_status.dart';

/// C3 — Payment journey orchestrator contracts (CI + VM).
void main() {
  group('C3 payment journey (orchestrator contracts)', () {
    test('credit-only checkout detected by orchestrator', () {
      expect(
        PaymentOrchestrator.isCreditOnlyCheckout({
          'orderId': null,
          'amountPaise': 0,
          'autoSettledFromCredit': true,
        }),
        isTrue,
      );
      expect(
        PaymentOrchestrator.isCreditOnlyCheckout({
          'orderId': 'order_abc',
          'amountPaise': 150000,
        }),
        isFalse,
      );
    });

    test('poll terminal success requires ledgerSynced', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'completed',
        'ledgerSynced': true,
      });
      var successCalled = false;
      final handled = PaymentOrchestrator.handlePollResult(
        poll: poll,
        onSuccess: () => successCalled = true,
        onFailed: (_) {},
        onGatewayUnavailable: (_) {},
      );
      expect(handled, isTrue);
      expect(successCalled, isTrue);
    });

    test('poll SUCCESS without ledgerSynced stays non-terminal', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'recorded',
        'ledgerSynced': false,
      });
      final handled = PaymentOrchestrator.handlePollResult(
        poll: poll,
        onSuccess: () => fail('should not succeed'),
        onFailed: (_) {},
        onGatewayUnavailable: (_) {},
      );
      expect(handled, isFalse);
    });

    test('reconcile_failed surfaces as failure', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'reconcile_failed',
        'detail': 'Ledger sync lag',
      });
      String? msg;
      PaymentOrchestrator.handlePollResult(
        poll: poll,
        onSuccess: () {},
        onFailed: (m) => msg = m,
        onGatewayUnavailable: (_) {},
      );
      expect(msg, isNotNull);
    });
  });
}
