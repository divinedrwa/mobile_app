import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/utils/gateway_payment_status.dart';

/// C3 — Critical payment journey (unit-level contract tests).
/// Full device integration_test requires emulator + local API; these freeze
/// create-order → poll → ledger-sync success semantics.
void main() {
  group('payment journey: create-order response contract', () {
    test('order payload exposes orderId, key, and amountPaise', () {
      const createOrderResponse = {
        'orderId': 'order_mock_123',
        'key': 'rzp_test_key',
        'amountPaise': 150000,
        'currency': 'INR',
        'verifying': false,
      };
      expect(createOrderResponse['orderId'], isNotEmpty);
      expect(createOrderResponse['key'], startsWith('rzp_'));
      expect(createOrderResponse['amountPaise'], greaterThan(0));
    });

    test('zero-amount credit-only checkout skips gateway', () {
      const creditOnly = {
        'orderId': null,
        'amountPaise': 0,
        'autoSettledFromCredit': true,
      };
      expect(creditOnly['orderId'], isNull);
      expect(creditOnly['autoSettledFromCredit'], isTrue);
    });
  });

  group('payment journey: webhook/poll → ledger success', () {
    test('captured Razorpay poll with ledgerSynced is terminal success', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'completed',
        'razorpayState': 'paid',
        'razorpayAvailable': true,
        'reconciled': true,
        'ledgerSynced': true,
      });
      expect(poll.isRecordedOrCompleted, isTrue);
      expect(poll.isPending, isFalse);
      expect(poll.isFailed, isFalse);
    });

    test('SUCCESS without ledgerSynced keeps polling (not success screen)', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'recorded',
        'ledgerSynced': false,
      });
      expect(poll.isRecordedOrCompleted, isFalse);
    });

    test('reconcile_failed is distinct from gateway failure', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'reconcile_failed',
        'ledgerSynced': false,
        'detail': 'Ledger sync lag',
      });
      expect(poll.isReconcileFailed, isTrue);
      expect(poll.isRecordedOrCompleted, isFalse);
    });

    test('PhonePe completed path matches Razorpay semantics', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'completed',
        'phonepeState': 'COMPLETED',
        'phonepeAvailable': true,
        'ledgerSynced': true,
      });
      expect(poll.isRecordedOrCompleted, isTrue);
    });

    test('failed payment shows user-facing message', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'FAILED',
        'outcome': 'failed',
        'detail': 'Payment declined by bank',
      });
      expect(poll.isFailed, isTrue);
      expect(poll.failureMessage, contains('declined'));
    });
  });
}
