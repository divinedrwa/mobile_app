/// Shared payment-mode helpers used by the maintenance providers, the
/// cycle-detail screen, and the invoice PDF.

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

/// The resident's own villa row in the dashboard's society-wide `residents[]`
/// carries the payment mode for that cycle. Returns the raw mode string.
String? paymentModeForVilla(Map<String, dynamic> dash, String? villaId) {
  if (villaId == null || villaId.isEmpty) return null;
  final residents = dash['residents'];
  if (residents is List) {
    for (final r in residents) {
      if (r is Map && r['residentId']?.toString() == villaId) {
        final mode = r['paymentMode']?.toString();
        return (mode == null || mode.isEmpty) ? null : mode;
      }
    }
  }
  return null;
}
