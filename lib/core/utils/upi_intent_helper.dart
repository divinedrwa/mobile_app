/// Builds NPCI UPI intent URIs for opening PhonePe / GPay / Paytm.
///
/// For a **bank/merchant QR** the original signed payload is replayed
/// *verbatim* — every field (`pa`, `pn`, `mc`, `mode`, `sign`, `orgid`, `tid`…)
/// is kept byte-for-byte and only `am`/`cu`/`tn` are set. This is essential:
///
///  * The transaction must stay **person-to-merchant (P2M)**. Dropping `mc`/
///    `sign` downgrades it to person-to-person (P2P), which hits NPCI's
///    per-payee "maximum payments in 24 hours" inbound cap — fine for a
///    resident, fatal for a society VPA collecting from everyone.
///  * The `sign` is base64 (`+`, `/`, `=`). Decoding then re-encoding it — e.g.
///    via `Uri(queryParameters:)` — corrupts it, and the payment app then
///    can't verify the merchant. So we never parse/rebuild the query; we edit
///    the raw string.
///
/// A manual UPI VPA (`UPI_VPA`, a personal address with no signed payload)
/// falls back to a plain P2P intent, which is correct for that case.
class UpiIntentHelper {
  static const int _maxTnLength = 50;

  /// Build `upi://pay?...` for launching a UPI app.
  static String buildPaymentIntent({
    required String vpa,
    required double amount,
    required String remark,
    String? payeeName,
    String? upiPayUri,
  }) {
    final tn = _sanitizeRemark(remark);
    final amountStr = amount.toStringAsFixed(2);

    final raw = upiPayUri?.trim();
    if (raw != null &&
        raw.toLowerCase().startsWith('upi://pay') &&
        raw.contains('?')) {
      return _withTransactionFields(raw, amountStr, tn);
    }

    // Manual UPI VPA (personal) → plain P2P intent.
    final buf = StringBuffer('upi://pay?pa=${vpa.trim()}');
    final pn = payeeName?.trim() ?? '';
    if (pn.isNotEmpty) buf.write('&pn=${Uri.encodeComponent(pn)}');
    buf.write('&am=$amountStr');
    buf.write('&cu=INR');
    if (tn.isNotEmpty) buf.write('&tn=${Uri.encodeComponent(tn)}');
    return buf.toString();
  }

  /// Keep every param from [uri] byte-for-byte, replacing only am/cu/tn so the
  /// merchant identity and signature are preserved exactly as scanned.
  static String _withTransactionFields(String uri, String amount, String tn) {
    final noFragment = uri.split('#').first;
    final qIndex = noFragment.indexOf('?');
    final path = noFragment.substring(0, qIndex);
    final query = noFragment.substring(qIndex + 1);

    final kept = query
        .split('&')
        .where((p) => p.isNotEmpty)
        .where((p) {
          final key = p.split('=').first.toLowerCase();
          return key != 'am' && key != 'cu' && key != 'tn';
        })
        .toList();

    kept.add('am=$amount');
    kept.add('cu=INR');
    if (tn.isNotEmpty) kept.add('tn=${Uri.encodeComponent(tn)}');

    return '$path?${kept.join('&')}';
  }

  static String _sanitizeRemark(String remark) {
    var s = remark.trim().replaceAll('/', '-').replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > _maxTnLength) {
      s = s.substring(0, _maxTnLength);
    }
    return s;
  }
}
