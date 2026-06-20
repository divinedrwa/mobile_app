// Shared payment-mode helpers used by the maintenance providers, the
// cycle-detail screen, and the invoice PDF.

/// Human label for a backend payment-mode string. Returns null when unknown,
/// so callers can fall back to a generic "Amount paid".
String? prettyPaymentMode(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  switch (raw.toUpperCase()) {
    case 'CASH':
      return 'Cash';
    case 'UPI':
      return 'UPI';
    case 'BANK_TRANSFER':
      return 'Bank transfer';
    case 'CHEQUE':
      return 'Cheque';
    case 'PHONEPE':
      return 'PhonePe';
    case 'RAZORPAY':
      return 'Razorpay';
    case 'ONLINE':
      return 'Online';
    case 'RECORDED':
      return 'Recorded by admin';
    default:
      return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }
}

/// Payment metadata for a villa row in the maintenance dashboard payload.
class VillaPaymentDetails {
  const VillaPaymentDetails({
    this.paymentMode,
    this.transactionId,
    this.receiptNumber,
  });

  final String? paymentMode;
  final String? transactionId;
  final String? receiptNumber;
}

/// The resident's own villa row in the dashboard's society-wide `residents[]`
/// carries the payment mode for that cycle. Returns the raw mode string.
String? paymentModeForVilla(Map<String, dynamic> dash, String? villaId) {
  return paymentDetailsForVilla(dash, villaId)?.paymentMode;
}

/// Payment mode, gateway reference, and receipt number for a villa in the
/// selected billing period (from `/residents/maintenance-dashboard`).
VillaPaymentDetails? paymentDetailsForVilla(
  Map<String, dynamic> dash,
  String? villaId,
) {
  if (villaId == null || villaId.isEmpty) return null;
  final residents = dash['residents'];
  if (residents is! List) return null;

  for (final r in residents) {
    if (r is! Map) continue;
    final id = r['residentId']?.toString() ?? r['villaId']?.toString();
    if (id != villaId) continue;

    final mode = r['paymentMode']?.toString();
    final txn = r['transactionId']?.toString();
    final receipt = r['receiptNumber']?.toString();
    return VillaPaymentDetails(
      paymentMode: (mode == null || mode.isEmpty) ? null : mode,
      transactionId: (txn == null || txn.isEmpty) ? null : txn,
      receiptNumber: (receipt == null || receipt.isEmpty) ? null : receipt,
    );
  }
  return null;
}
