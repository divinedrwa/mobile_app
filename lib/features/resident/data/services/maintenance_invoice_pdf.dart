import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/amount_in_words.dart';
import '../../../../shared/models/user_model.dart';
import '../models/expense_breakdown_model.dart';
import '../models/maintenance_due_model.dart';
import '../repositories/maintenance_repository.dart';
import '../utils/payment_mode.dart';

// ---- palette ----
const _navy = PdfColor.fromInt(0xFF14215B);
const _ink = PdfColor.fromInt(0xFF1F2937);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);
const _green = PdfColor.fromInt(0xFF16A34A);
const _greenSoft = PdfColor.fromInt(0xFFE9F7EF);
const _red = PdfColor.fromInt(0xFFDC2626);
const _catPalette = <PdfColor>[
  PdfColor.fromInt(0xFF2563EB),
  PdfColor.fromInt(0xFF0EA5E9),
  PdfColor.fromInt(0xFFF59E0B),
  PdfColor.fromInt(0xFF8B5CF6),
  PdfColor.fromInt(0xFFEC4899),
  PdfColor.fromInt(0xFF14B8A6),
];

/// Gathers per-cycle data (expense split, payment mode, balances) for the
/// requesting resident and builds the A4 invoice. Shared by the hub and the
/// cycle-detail screen.
Future<Uint8List> buildInvoiceForPayment({
  required MaintenanceRepository repo,
  required UserModel? user,
  required MaintenanceDueModel m,
  required DateTime generatedAt,
  String? upiId,
  String? payeeName,
  String? upiQrCodeUrl,
  String? letterheadUrl,
  String? signatureUrl,
  String? stampUrl,
  String? societyAddress,
}) async {
  ExpenseBreakdown? breakdown;
  String? paymentMode;
  String? transactionId;
  String? receiptNumber;
  try {
    final dash = await repo.getFinancialDashboard(month: m.month, year: m.year);
    breakdown = ExpenseBreakdown.fromDashboard(dash, allowFallback: false);
    final details = paymentDetailsForVilla(dash, user?.villaId);
    paymentMode = prettyPaymentMode(details?.paymentMode);
    transactionId = details?.transactionId;
    receiptNumber = details?.receiptNumber;
  } catch (_) {
    breakdown = null;
  }

  final villaLabel = (user?.propertyDisplayName ??
          user?.unitDisplayName ??
          [user?.villaBlock, user?.villaNumber]
              .where((e) => e != null && e.isNotEmpty)
              .join(' '))
      .trim();
  // The cycle's actual maintenance charge (what the resident is billed). The
  // expense breakdown is informational and may differ; the invoice total must
  // be the charge, not the computed per-home expense share.
  final billedAmount = m.expectedAmount > 0 ? m.expectedAmount : m.amount;

  // Fetch the admin-uploaded UPI QR + society letterhead images (Cloudinary
  // URLs) so they can be embedded in the invoice. Best-effort: a failure on
  // the QR falls back to a generated QR / placeholder; a failure on the
  // letterhead falls back to the bundled default artwork.
  final qrImageBytes = await _fetchImageBytes(upiQrCodeUrl);
  final letterheadBytes = await _fetchImageBytes(letterheadUrl);
  final signatureBytes = await _fetchImageBytes(signatureUrl);
  final stampBytes = await _fetchImageBytes(stampUrl);

  return buildMaintenanceInvoicePdf(
    societyName: user?.societyName ?? 'Your Society',
    societyAddress: societyAddress,
    residentName: user?.name ?? '',
    villaLabel: villaLabel,
    month: m.month,
    year: m.year,
    receiptNo: receiptNumber?.isNotEmpty == true ? receiptNumber! : m.cycleKey,
    billedAmount: billedAmount,
    paidAt: m.paidAt,
    status: m.status,
    paymentMode: paymentMode,
    transactionId: transactionId,
    breakdown: breakdown,
    generatedAt: generatedAt,
    previousBalance: m.previousDue,
    paymentsReceived: m.cashPaidAmount,
    adjustments: m.creditApplied,
    amountDue: m.remainingDue,
    upiId: upiId,
    payeeName: payeeName,
    qrImageBytes: qrImageBytes,
    letterheadBytes: letterheadBytes,
    signatureBytes: signatureBytes,
    stampBytes: stampBytes,
  );
}

/// Stable cache filename for a cycle's invoice. Includes the month/year and a
/// paid/due tag so the file regenerates automatically when a cycle is paid,
/// while staying friendly when shared. (Other changes — e.g. accruing dues —
/// are handled by the "Regenerate" action.)
String invoiceCacheFilename(MaintenanceDueModel m) {
  final month = DateFormat('MMM_yyyy').format(DateTime(m.year, m.month));
  final tag = m.status.toUpperCase() == 'PAID' ? 'PAID' : 'DUE';
  return 'Maintenance_Invoice_${month}_$tag.pdf';
}

/// Best-effort fetch of a remote image as bytes. Returns null on any failure
/// or when [url] is empty, so callers can fall back gracefully.
Future<Uint8List?> _fetchImageBytes(String? url) async {
  final u = url?.trim() ?? '';
  if (u.isEmpty) return null;
  try {
    final resp = await Dio().get<List<int>>(
      u,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = resp.data;
    if (data != null && data.isNotEmpty) return Uint8List.fromList(data);
  } catch (_) {
    // ignore — caller falls back
  }
  return null;
}

/// Builds a professional maintenance invoice on the society letterhead. The
/// breakup rows are the resident's per-home share of each society expense plus
/// a reserve line (summing to the maintenance amount). The page is rendered in
/// US-Letter format to match the letterhead artwork, which is drawn full-page
/// behind the content.
Future<Uint8List> buildMaintenanceInvoicePdf({
  required String societyName,
  String? societyAddress,
  required String residentName,
  required String villaLabel,
  required int month,
  required int year,
  required String receiptNo,
  required double billedAmount,
  required DateTime? paidAt,
  required String status,
  required ExpenseBreakdown? breakdown,
  required DateTime generatedAt,
  String? paymentMode,
  String? transactionId,
  double previousBalance = 0,
  double paymentsReceived = 0,
  double adjustments = 0,
  double amountDue = 0,
  // Real society UPI details (when configured); other contact/legal fields
  // remain placeholders to be supplied later.
  String? upiId,
  String? payeeName,
  // Admin-uploaded UPI QR image bytes (preferred over a generated QR).
  Uint8List? qrImageBytes,
  // Admin-uploaded society letterhead bytes (preferred over the bundled asset).
  Uint8List? letterheadBytes,
  // Admin-uploaded authorised-signature and stamp bytes (else placeholders).
  Uint8List? signatureBytes,
  Uint8List? stampBytes,
}) async {
  final money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final dFmt = DateFormat('d MMM yyyy');

  final baseFont =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Hind-Regular.ttf'));
  final boldFont =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Hind-SemiBold.ttf'));

  // Society letterhead artwork, drawn full-page behind the invoice content.
  // Prefer the admin-uploaded letterhead; fall back to the bundled default.
  pw.MemoryImage? letterhead;
  if (letterheadBytes != null && letterheadBytes.isNotEmpty) {
    letterhead = pw.MemoryImage(letterheadBytes);
  } else {
    try {
      letterhead = pw.MemoryImage(
          (await rootBundle.load('assets/branding/letterhead.png'))
              .buffer
              .asUint8List());
    } catch (_) {
      letterhead = null;
    }
  }

  final qrImage = (qrImageBytes != null && qrImageBytes.isNotEmpty)
      ? pw.MemoryImage(qrImageBytes)
      : null;
  final signatureImage = (signatureBytes != null && signatureBytes.isNotEmpty)
      ? pw.MemoryImage(signatureBytes)
      : null;
  final stampImage = (stampBytes != null && stampBytes.isNotEmpty)
      ? pw.MemoryImage(stampBytes)
      : null;

  final statusUpper = status.toUpperCase();
  // Treat fully-settled cycles (paid outright or auto-settled from credit) as
  // paid; a cycle with a part payment but a remaining balance is "partial".
  final isPaid = statusUpper == 'PAID' || statusUpper == 'AUTO_SETTLED';
  final isPartial = !isPaid &&
      (statusUpper == 'PARTIAL' ||
          ((paymentsReceived + adjustments) > 0 && amountDue > 0));
  final fyLabel = financialYearLabel(month, year);
  final documentTitle = isPaid ? 'PAYMENT RECEIPT' : 'MAINTENANCE INVOICE';
  final cycleKeyPattern = RegExp(r'^\d{4}-\d{2}$');
  final invoiceNo = receiptNo.trim().isNotEmpty &&
          !cycleKeyPattern.hasMatch(receiptNo.trim())
      ? receiptNo.trim()
      : 'INV-${receiptNo.trim().isNotEmpty ? receiptNo.trim() : '$year-${month.toString().padLeft(2, '0')}'}';
  final periodStart = DateTime(year, month, 1);
  final periodEnd = DateTime(year, month + 1, 0);
  final billingPeriod = (month >= 1 && month <= 12)
      ? '${dFmt.format(periodStart)} – ${dFmt.format(periodEnd)}'
      : '—';

  // The headline "Total Amount" is DERIVED from the figures that must
  // reconcile, so it can never show an unexplained gap against Amount Paid/Due
  // (the backend's expectedAmount/charge can diverge from what was actually
  // paid, so we don't trust it as the total):
  //  - Paid/settled cycle  → Total = what was actually paid (cash + credit),
  //    so "Total Amount" always equals "Amount Paid".
  //  - Unpaid/partial cycle → Total = Amount Due + Payments + Credits − Previous,
  //    so the column reconciles to the authoritative Amount Due. This equals
  //    the real cycle charge when the figures are consistent.
  // The passed cycle charge is only a last-resort fallback.
  final amountPaidTotal = paymentsReceived + adjustments;
  final unpaidCharge =
      amountDue + paymentsReceived + adjustments - previousBalance;
  final billedTotal = isPaid
      ? (amountPaidTotal > 0 ? amountPaidTotal : billedAmount)
      : (unpaidCharge > 0
          ? unpaidCharge
          : (billedAmount > 0 ? billedAmount : amountDue));

  // Breakup rows: per-home expense shares + a reserve line that reconciles them
  // to the billed total. The invoice prints whole rupees, so we round every row
  // and make the reserve the exact integer "plug" — the printed rows then ALWAYS
  // sum to the printed Total (no per-category rounding drift).
  final hasSplit = breakdown != null && breakdown.hasData && breakdown.hasMemberSplit;
  final totalRupees = billedTotal.round();
  final rows = <_Row>[];
  if (hasSplit) {
    var categoryRupees = 0;
    for (var i = 0; i < breakdown.categories.length; i++) {
      final c = breakdown.categories[i];
      final share = breakdown.shareOfCategory(c).round();
      categoryRupees += share;
      rows.add(_Row(
        color: _catPalette[i % _catPalette.length],
        name: c.name,
        desc: 'Your share of society ${c.name.toLowerCase()}',
        amount: share.toDouble(),
      ));
    }
    final reserve = totalRupees - categoryRupees;
    if (reserve != 0) {
      rows.add(_Row(
        color: const PdfColor.fromInt(0xFF94A3B8),
        name: reserve >= 0 ? 'Society reserve' : 'From reserves',
        desc: reserve >= 0
            ? 'Contribution to common society reserves'
            : 'Shortfall covered from society reserves',
        amount: reserve.toDouble(),
      ));
    }
  } else {
    rows.add(_Row(
      color: _catPalette[0],
      name: 'Maintenance charges',
      desc: 'Monthly maintenance for the society',
      amount: totalRupees.toDouble(),
    ));
  }

  final trimmedUpi = upiId?.trim() ?? '';
  final hasUpi = trimmedUpi.isNotEmpty && !trimmedUpi.startsWith('[');
  final upi = trimmedUpi;
  // Build a scannable UPI deep link when a real VPA is configured. The amount
  // due (for unpaid invoices) is pre-filled so any UPI app opens ready to pay.
  String? upiUri;
  if (hasUpi) {
    final payee = (payeeName?.trim().isNotEmpty ?? false)
        ? payeeName!.trim()
        : societyName;
    final qrAmount = isPaid ? 0.0 : amountDue;
    final note = 'Maintenance $month/$year';
    upiUri = 'upi://pay?pa=${Uri.encodeComponent(trimmedUpi)}'
        '&pn=${Uri.encodeComponent(payee)}'
        '${qrAmount > 0 ? '&am=${qrAmount.toStringAsFixed(2)}' : ''}'
        '&tn=${Uri.encodeComponent(note)}'
        '&cu=INR';
  }
  // Letter format matches the letterhead artwork aspect ratio. Margins clear
  // the letterhead's printed header band (top) and footer band (bottom) so the
  // invoice content never overlaps the branding.
  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.fromLTRB(38, 150, 38, 72),
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    buildBackground: letterhead == null
        ? null
        : (ctx) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(letterhead!, fit: pw.BoxFit.fill),
            ),
  );

  final showPay = !isPaid &&
      amountDue > 0 &&
      hasUpi &&
      (qrImage != null || upiUri != null);

  final amountWords = amountInWordsIndian(billedTotal);
  final generatedStamp = DateFormat('d MMM yyyy, HH:mm').format(generatedAt.toLocal());

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      build: (ctx) => [
        _titleBar(documentTitle, isPaid, isPartial),
        pw.SizedBox(height: 12),
        _partiesBlock(
          name: residentName,
          unit: villaLabel,
          society: societyName,
          societyAddress: societyAddress,
          invoiceNo: invoiceNo,
          billingPeriod: billingPeriod,
          financialYear: fyLabel,
          dFmt: dFmt,
          paidAt: paidAt,
          generatedAt: generatedAt,
          dueDate: periodEnd,
          isPaid: isPaid,
          paymentMode: isPaid ? paymentMode : null,
          transactionId: isPaid ? transactionId : null,
        ),
        pw.SizedBox(height: 16),
        _breakupTable(rows, billedTotal, money, amountWords),
        pw.SizedBox(height: 16),
        _totalsAndPay(
          billedTotal,
          previousBalance,
          paymentsReceived,
          adjustments,
          isPaid ? amountPaidTotal : amountDue,
          isPaid,
          money,
          upi,
          upiUri,
          qrImage,
          showPay,
        ),
        pw.SizedBox(height: 20),
        _signOff(
          societyName: societyName,
          signatureImage: signatureImage,
          stampImage: stampImage,
          financialYear: fyLabel,
          generatedStamp: generatedStamp,
          invoiceNo: invoiceNo,
        ),
      ],
    ),
  );

  return doc.save();
}

// ============================================================
// Sections — clean, minimal layout (society branding comes from the letterhead)
// ============================================================

pw.Widget _statusPill(bool isPaid, bool isPartial) {
  final PdfColor bg;
  final PdfColor fg;
  final String label;
  if (isPaid) {
    bg = _greenSoft;
    fg = _green;
    label = 'PAID';
  } else if (isPartial) {
    bg = const PdfColor.fromInt(0xFFFEF3C7);
    fg = const PdfColor.fromInt(0xFFB45309);
    label = 'PART-PAID';
  } else {
    bg = const PdfColor.fromInt(0xFFFDECEC);
    fg = _red;
    label = 'UNPAID';
  }
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(label,
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: fg)),
  );
}

/// Document title + status, with a thin accent rule.
pw.Widget _titleBar(String documentTitle, bool isPaid, bool isPartial) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Text(documentTitle,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    letterSpacing: 0.4)),
          ),
          _statusPill(isPaid, isPartial),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 1.4, color: _navy),
    ],
  );
}

/// Two columns: who it's billed to (left) and the invoice meta (right).
pw.Widget _partiesBlock({
  required String name,
  required String unit,
  required String society,
  String? societyAddress,
  required String invoiceNo,
  required String billingPeriod,
  required String financialYear,
  required DateFormat dFmt,
  required DateTime? paidAt,
  required DateTime generatedAt,
  required DateTime dueDate,
  required bool isPaid,
  String? paymentMode,
  String? transactionId,
}) {
  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(k,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(width: 10),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 9, color: _ink, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 5,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BILLED TO',
                style: pw.TextStyle(
                    fontSize: 8,
                    color: _muted,
                    letterSpacing: 0.6,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(unit.isNotEmpty ? unit : 'Your unit',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
            if (name.isNotEmpty)
              pw.Text(name,
                  style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
            pw.Text(society,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            if ((societyAddress ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                societyAddress!.trim(),
                style: const pw.TextStyle(fontSize: 8.5, color: _muted),
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(width: 28),
      pw.Expanded(
        flex: 5,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            kv('Document No.', invoiceNo),
            if (financialYear.isNotEmpty) kv('Financial Year', financialYear),
            kv('Billing Period', billingPeriod),
            kv('Invoice Date', dFmt.format(paidAt ?? generatedAt)),
            kv('Due Date', dFmt.format(dueDate)),
            if (isPaid && paymentMode != null && paymentMode.isNotEmpty)
              kv('Paid Via', paymentMode),
            if (isPaid &&
                transactionId != null &&
                transactionId.trim().isNotEmpty)
              kv('Transaction Ref.', transactionId.trim()),
          ],
        ),
      ),
    ],
  );
}

/// Clean line-item table with amount in words below the total.
pw.Widget _breakupTable(
  List<_Row> rows,
  double total,
  NumberFormat money,
  String amountWords,
) {
  String amt(double v) => money.format(v).replaceAll('₹', '').trim();

  pw.Widget line(String particulars, String amount,
          {bool bold = false, PdfColor color = _ink, double size = 9.5}) =>
      pw.Row(children: [
        pw.Expanded(
          child: pw.Text(particulars,
              style: pw.TextStyle(
                  fontSize: size,
                  color: color,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Text(amount,
            style: pw.TextStyle(
                fontSize: size,
                color: color,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('PARTICULARS',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    letterSpacing: 0.4)),
          ),
          pw.Text('AMOUNT (₹)',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                  letterSpacing: 0.4)),
        ]),
      ),
      for (final r in rows)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
          ),
          child: line(r.name, amt(r.amount)),
        ),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: line('Total Amount', money.format(total),
            bold: true, color: _navy, size: 11),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Amount in words: $amountWords',
        style: const pw.TextStyle(fontSize: 8.5, color: _muted),
      ),
    ],
  );
}

/// Bottom block: scan-&-pay (only when there's an amount due) on the left,
/// the running totals on the right.
pw.Widget _totalsAndPay(
  double total,
  double prevBalance,
  double received,
  double adjustments,
  double finalAmount,
  bool isPaid,
  NumberFormat money,
  String upi,
  String? upiUri,
  pw.MemoryImage? qrImage,
  bool showPay,
) {
  final totals = _totalsBox(
      total, prevBalance, received, adjustments, finalAmount, isPaid, money);
  if (!showPay) {
    return pw.Row(children: [
      pw.Spacer(flex: 4),
      pw.Expanded(flex: 6, child: totals),
    ]);
  }
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(flex: 6, child: _payBox(upi, upiUri, qrImage)),
      pw.SizedBox(width: 18),
      pw.Expanded(flex: 6, child: totals),
    ],
  );
}

pw.Widget _totalsBox(double total, double prevBalance, double received,
    double adjustments, double finalAmount, bool isPaid, NumberFormat money) {
  pw.Widget row(String k, String v, {PdfColor color = _ink}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 9.5,
                    color: color,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  final accent = isPaid ? _green : _red;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Ledger: starts from this cycle's charge, brings forward arrears, then
      // (for unpaid) subtracts what's been paid to reach the amount due. For a
      // paid receipt Total already equals what was paid, so no further lines.
      row('Total Amount', money.format(total)),
      if (!isPaid && prevBalance > 0)
        row('Previous Outstanding', '+ ${money.format(prevBalance)}'),
      if (!isPaid && received > 0)
        row('Payments Received', '- ${money.format(received)}', color: _green),
      if (!isPaid && adjustments > 0)
        row('Advance Credit Applied', '- ${money.format(adjustments)}',
            color: _green),
      pw.SizedBox(height: 4),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: isPaid ? _greenSoft : const PdfColor.fromInt(0xFFFDECEC),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(isPaid ? 'AMOUNT PAID' : 'AMOUNT DUE',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
            pw.Text(money.format(finalAmount),
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _payBox(String upi, String? upiUri, pw.MemoryImage? qrImage) {
  final hasQr = qrImage != null || upiUri != null;
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (hasQr) ...[
          pw.SizedBox(
            width: 68,
            height: 68,
            child: qrImage != null
                ? pw.Image(qrImage, fit: pw.BoxFit.contain)
                : pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: upiUri!,
                    color: _ink,
                    drawText: false,
                  ),
          ),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SCAN & PAY',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      letterSpacing: 0.4)),
              pw.SizedBox(height: 3),
              pw.Text(
                  hasQr
                      ? 'Scan the QR with any UPI app'
                      : 'Pay to the UPI ID below',
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
              pw.SizedBox(height: 5),
              pw.Text('UPI ID',
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
              pw.Text(upi,
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Footer note (left) + authorised signature & stamp (right).
pw.Widget _signOff({
  required String societyName,
  pw.MemoryImage? signatureImage,
  pw.MemoryImage? stampImage,
  required String financialYear,
  required String generatedStamp,
  required String invoiceNo,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Text(
              'This is a computer-generated document. For any discrepancy, '
              'please contact the management office.',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          pw.SizedBox(width: 16),
          if (stampImage != null) ...[
            pw.SizedBox(
                width: 56,
                height: 56,
                child: pw.Image(stampImage, fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 10),
          ],
          pw.SizedBox(
            width: 150,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (signatureImage != null)
                  pw.Container(
                    height: 32,
                    alignment: pw.Alignment.center,
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 28),
                pw.Container(height: 0.7, color: _line),
                pw.SizedBox(height: 3),
                pw.Text('Authorised Signatory',
                    style: pw.TextStyle(
                        fontSize: 8.5,
                        color: _ink,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('For $societyName',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 0.5, color: _line),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (financialYear.isNotEmpty)
            pw.Text(
              financialYear,
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            )
          else
            pw.SizedBox(),
          pw.Text(
            'Generated $generatedStamp',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
          pw.Text(
            invoiceNo,
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ),
    ],
  );
}

class _Row {
  _Row(
      {required this.color,
      required this.name,
      required this.desc,
      required this.amount});
  final PdfColor color;
  final String name;
  final String desc;
  final double amount;
}
