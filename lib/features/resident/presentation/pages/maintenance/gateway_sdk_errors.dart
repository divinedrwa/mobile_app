/// Razorpay / PhonePe SDK error helpers for gateway checkout screens.
class GatewaySdkErrors {
  GatewaySdkErrors._();

  /// User cancelled checkout or the Razorpay window timed out — no server poll needed.
  static bool shouldSkipServerVerifyAfterRazorpayFailure({
    String? message,
    int? code,
  }) {
    final m = (message ?? '').trim().toLowerCase();
    if (m == 'timeout' || m.contains('timed out')) return true;
    if (m.contains('cancel')) return true;
    // razorpay_flutter codes: 0=NETWORK_ERROR, 1=INVALID_OPTIONS, 2=PAYMENT_CANCELLED,
    // 3=TLS_ERROR, 100=UNKNOWN_ERROR. Only an explicit user cancellation (2) is safe to
    // skip — NETWORK_ERROR/UNKNOWN may have captured the payment, so they must be polled.
    if (code == 2) return true;
    return false;
  }

  static String formatRazorpayFailureMessage(String? message) {
    final m = (message ?? '').trim();
    if (m.isEmpty) return 'Payment could not be completed. Tap Retry to try again.';
    if (m.toLowerCase() == 'timeout' || m.toLowerCase().contains('timed out')) {
      return 'Payment window closed. Tap Retry and complete checkout within a few minutes.';
    }
    if (m.toLowerCase().contains('cancel')) {
      return 'Payment cancelled. Tap Retry when you are ready to pay.';
    }
    return m;
  }
}
