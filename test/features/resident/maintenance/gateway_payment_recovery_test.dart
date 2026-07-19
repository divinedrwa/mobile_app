import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/services/payment_orchestrator.dart';
import 'package:divine_app/features/resident/presentation/pages/maintenance/gateway_payment_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GatewayPaymentRecovery', () {
    test('tryRecover completes when no navigator context is available', () async {
      await expectLater(GatewayPaymentRecovery.tryRecover(), completes);
    });

    test('PaymentOrchestrator.recoverPendingPayment does not recurse', () async {
      // Regression: 537367b wired orchestrator ↔ recovery in a circle → StackOverflowError
      // on every home load / app resume.
      await expectLater(PaymentOrchestrator.recoverPendingPayment(), completes);
    });
  });
}
