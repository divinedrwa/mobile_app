import 'package:flutter/widgets.dart';

import '../../features/resident/presentation/pages/maintenance/gateway_payment_recovery.dart';

/// Polls server for a persisted in-flight Razorpay/PhonePe payment when the app resumes.
class GatewayPaymentLifecycleBinding extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GatewayPaymentRecovery.tryRecover();
      });
    }
  }
}
