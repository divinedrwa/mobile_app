import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/utils/gateway_payment_status.dart';

void main() {
  group('GatewayPaymentPollResult', () {
    test('fromJson detects success outcomes', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'SUCCESS',
        'outcome': 'completed',
        'razorpayState': 'paid',
        'razorpayAvailable': true,
        'reconciled': true,
      });
      expect(poll.isRecordedOrCompleted, isTrue);
      expect(poll.isFailed, isFalse);
    });

    test('fromJson detects PhonePe failure', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'FAILED',
        'outcome': 'failed',
        'phonepeState': 'FAILED',
        'phonepeAvailable': true,
      });
      expect(poll.isFailed, isTrue);
      expect(poll.failureMessage, contains('failed'));
    });

    test('fromJson detects gateway unavailable', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'UNKNOWN',
        'outcome': 'gateway_unavailable',
        'phonepeAvailable': false,
        'detail': 'PhonePe is not configured',
      });
      expect(poll.isGatewayUnavailable, isTrue);
    });

    test('empty() is unknown and unavailable', () {
      final poll = GatewayPaymentPollResult.empty();
      expect(poll.outcome, 'unknown');
      expect(poll.gatewayAvailable, isFalse);
    });

    test('pending is not terminal', () {
      final poll = GatewayPaymentPollResult.fromJson({
        'status': 'PENDING',
        'outcome': 'pending',
        'phonepeState': 'PENDING',
      });
      expect(poll.isPending, isTrue);
      expect(poll.isRecordedOrCompleted, isFalse);
      expect(poll.isFailed, isFalse);
    });
  });
}
