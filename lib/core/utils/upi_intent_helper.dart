/// Builds NPCI UPI intent URIs for opening PhonePe / GPay / Paytm.
///
/// Three payload shapes, three strategies:
///
///  * **Signed bank QR** (`sign=` present): the signature covers the original
///    payload, so it is replayed *verbatim* — every field (`pa`, `pn`, `mc`,
///    `mode`, `sign`, `orgid`, `tid`…) kept byte-for-byte, only `am`/`cu`/`tn`
///    set. The `sign` is base64 (`+`, `/`, `=`); decoding then re-encoding it
///    corrupts it, so the raw string is edited, never parsed/rebuilt.
///
///  * **Unsigned merchant QR** (`mc=` present, no `sign` — e.g. a Bank of
///    Maharashtra shop QR): replaying it verbatim gets DECLINED by payment
///    apps at pay time, because the intent then violates the NPCI linking
///    spec: no `tr` (transaction reference — required for merchant intents),
///    `mode=01` (claims "scanned QR" while arriving via deep link; intent is
///    `mode=04`), and a percent-encoded `pa` some apps reject as an invalid
///    VPA. So the params are decoded and rebuilt spec-correct: `pa` with a
///    literal `@`, `mode=04`, a fresh unique `tr` per attempt — while keeping
///    `mc`/`purpose` so the transaction stays **person-to-merchant (P2M)**.
///    Dropping `mc` would downgrade it to P2P, which hits NPCI's per-payee
///    "maximum payments in 24 hours" inbound cap — fine for a resident, fatal
///    for a society VPA collecting from everyone.
///
///  * **Manual UPI VPA** (`UPI_VPA`, a personal address with no payload):
///    plain P2P intent, which is correct for that case.
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
      if (_hasParam(raw, 'sign')) {
        return _withTransactionFields(raw, amountStr, tn);
      }
      return _rebuildUnsignedMerchantIntent(raw, amountStr, tn);
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

  static bool _hasParam(String uri, String name) {
    final query = uri.split('#').first.split('?').skip(1).join('?');
    return query.split('&').any((p) {
      final key = p.split('=').first.trim().toLowerCase();
      return key == name;
    });
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

  /// Rebuild an unsigned merchant QR into a spec-correct P2M *intent*:
  /// decoded `pa` (literal `@`), `mode=04` (intent channel), a unique `tr`,
  /// and `mc`/`purpose`/other merchant params preserved.
  static String _rebuildUnsignedMerchantIntent(
    String uri,
    String amount,
    String tn,
  ) {
    final noFragment = uri.split('#').first;
    final qIndex = noFragment.indexOf('?');
    final path = noFragment.substring(0, qIndex);
    final query = noFragment.substring(qIndex + 1);

    final kept = <String>[];
    for (final pair in query.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final key =
          (eq < 0 ? pair : pair.substring(0, eq)).trim().toLowerCase();
      // Transaction-specific fields are regenerated below; `mode` is replaced
      // because the QR's scan-channel value is wrong for a deep link.
      if (key == 'am' ||
          key == 'cu' ||
          key == 'tn' ||
          key == 'tr' ||
          key == 'mode') {
        continue;
      }
      final rawValue = eq < 0 ? '' : pair.substring(eq + 1);
      final decoded = Uri.decodeQueryComponent(rawValue);
      if (key == 'pa') {
        // VPA characters are URI-safe; keep '@' literal — some apps reject
        // a percent-encoded payee address as invalid.
        kept.add('pa=$decoded');
      } else {
        kept.add('$key=${Uri.encodeComponent(decoded)}');
      }
    }

    kept.add('mode=04');
    kept.add('tr=${_transactionRef()}');
    kept.add('am=$amount');
    kept.add('cu=INR');
    if (tn.isNotEmpty) kept.add('tn=${Uri.encodeComponent(tn)}');

    return '$path?${kept.join('&')}';
  }

  /// Alphanumeric merchant transaction reference, unique per attempt
  /// (NPCI allows up to 35 chars).
  static String _transactionRef() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'MNT$ts';
  }

  static String _sanitizeRemark(String remark) {
    var s = remark.trim().replaceAll('/', '-').replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > _maxTnLength) {
      s = s.substring(0, _maxTnLength);
    }
    return s;
  }
}
