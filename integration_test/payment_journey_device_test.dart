import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/services/payment_orchestrator.dart';
import 'package:divine_app/features/resident/data/utils/gateway_payment_status.dart';

/// C3 device E2E scaffold — run on emulator with local API:
/// `flutter test integration_test/payment_journey_device_test.dart -d <device>`
///
/// Skipped in VM/CI (no device, no live API).
@Skip('Requires emulator + local API — see integration_test/README.md')
void main() {
  test('login → due → create-order mock → poll success', () async {
    // Device test: wire MaintenanceRepository against sandbox API,
    // assert PaymentOrchestrator.handlePollResult on ledgerSynced poll.
    final poll = GatewayPaymentPollResult.fromJson({
      'status': 'SUCCESS',
      'outcome': 'completed',
      'ledgerSynced': true,
    });
    expect(
      PaymentOrchestrator.handlePollResult(
        poll: poll,
        onSuccess: () {},
        onFailed: (_) {},
        onGatewayUnavailable: (_) {},
      ),
      isTrue,
    );
  });
}
