import 'package:flutter/widgets.dart';

import '../../features/resident/data/services/payment_orchestrator.dart';

/// Polls server for a persisted in-flight Razorpay/PhonePe payment when the app resumes.
class GatewayPaymentLifecycleBinding extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PaymentOrchestrator.recoverPendingPayment();
      });
    }
  }
}
