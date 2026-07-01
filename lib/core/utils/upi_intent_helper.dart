/// Builds NPCI UPI intent URIs for opening PhonePe / GPay / Paytm.
///
/// The intent is a **plain person-to-person (P2P) request** — only `pa`, `pn`,
/// `am`, `cu` and `tn`. Merchant fields carried by a scanned bank QR (`mc`,
/// `tid`, `mode`, `sign`, `orgid`, `purpose`, `url`…) are deliberately dropped.
///
/// Why: an intent that carries `mc` is treated by GPay/PhonePe/Paytm as a
/// verified-merchant (P2M) payment and is refused unless it also carries the
/// original merchant signature (`sign`). A URI we rebuild from a decoded QR
/// cannot reproduce that signature, so the app opens but the payment fails.
/// Stripping the merchant fields makes the intent behave exactly like manually
/// typing the VPA — which is known to work for this account.
class UpiIntentHelper {
  static const int _maxTnLength = 50;

  /// Build `upi://pay?...` as a clean P2P intent.
  ///
  /// The exact `pa`/`pn` are taken from [upiPayUri] (the decoded bank QR) when
  /// present, because the separately-parsed [vpa] can be truncated for unusual
  /// merchant VPAs. Everything else on that URI is discarded.
  static String buildPaymentIntent({
    required String vpa,
    required double amount,
    required String remark,
    String? payeeName,
    String? upiPayUri,
  }) {
    var pa = vpa.trim();
    var pn = payeeName?.trim() ?? '';

    if (upiPayUri != null && upiPayUri.trim().isNotEmpty) {
      final base = Uri.tryParse(upiPayUri.trim());
      if (base != null && base.scheme == 'upi' && base.host == 'pay') {
        final qp = base.queryParameters;
        final qpPa = qp['pa']?.trim();
        if (qpPa != null && qpPa.isNotEmpty) pa = qpPa;
        final qpPn = qp['pn']?.trim();
        if (pn.isEmpty && qpPn != null && qpPn.isNotEmpty) pn = qpPn;
      }
    }

    final tn = _sanitizeRemark(remark);
    final amountStr = amount.toStringAsFixed(2);

    // Build the query manually so spaces encode as %20 (Dart's
    // Uri(queryParameters:) form-encodes them as '+', which some UPI apps
    // render/parse literally). VPA characters are all URL-safe, so `pa` is
    // written verbatim.
    final buf = StringBuffer('upi://pay?pa=$pa');
    if (pn.isNotEmpty) buf.write('&pn=${Uri.encodeComponent(pn)}');
    buf.write('&am=$amountStr');
    buf.write('&cu=INR');
    if (tn.isNotEmpty) buf.write('&tn=${Uri.encodeComponent(tn)}');
    return buf.toString();
  }

  static String _sanitizeRemark(String remark) {
    var s = remark.trim().replaceAll('/', '-').replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > _maxTnLength) {
      s = s.substring(0, _maxTnLength);
    }
    return s;
  }
}
