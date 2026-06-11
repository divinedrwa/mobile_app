import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../shared/models/user_model.dart';
import '../models/expense_breakdown_model.dart';
import '../models/maintenance_due_model.dart';
import '../repositories/maintenance_repository.dart';
import '../utils/payment_mode.dart';

// ---- palette ----
const _navy = PdfColor.fromInt(0xFF14215B);
const _navySoft = PdfColor.fromInt(0xFFEAF0FB);
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
}) async {
  ExpenseBreakdown? breakdown;
  String? paymentMode;
  try {
    final dash = await repo.getFinancialDashboard(month: m.month, year: m.year);
    breakdown = ExpenseBreakdown.fromDashboard(dash, allowFallback: false);
    paymentMode = prettyPaymentMode(paymentModeForVilla(dash, user?.villaId));
  } catch (_) {
    breakdown = null;
  }

  final villaLabel = (user?.propertyDisplayName ??
          user?.unitDisplayName ??
          [user?.villaBlock, user?.villaNumber]
              .where((e) => e != null && e.isNotEmpty)
              .join(' '))
      .trim();
  final amountPaid = m.cashPaidAmount > 0
      ? m.cashPaidAmount
      : (m.paidAmount > 0 ? m.paidAmount : m.amount);

  return buildMaintenanceInvoicePdf(
    societyName: user?.societyName ?? 'Your Society',
    residentName: user?.name ?? '',
    villaLabel: villaLabel,
    month: m.month,
    year: m.year,
    receiptNo: m.cycleKey,
    amountPaid: amountPaid,
    paidAt: m.paidAt,
    status: m.status,
    paymentMode: paymentMode,
    breakdown: breakdown,
    generatedAt: generatedAt,
    previousBalance: m.previousDue,
    paymentsReceived: m.cashPaidAmount,
    adjustments: m.creditApplied,
    amountDue: m.remainingDue,
  );
}

/// Builds an A4 professional maintenance invoice. The breakup rows are the
/// resident's per-home share of each society expense plus a reserve line
/// (summing to the maintenance amount). Society legal/contact details and the
/// QR / stamp / signature are placeholders to be supplied later.
Future<Uint8List> buildMaintenanceInvoicePdf({
  required String societyName,
  required String residentName,
  required String villaLabel,
  required int month,
  required int year,
  required String receiptNo,
  required double amountPaid,
  required DateTime? paidAt,
  required String status,
  required ExpenseBreakdown? breakdown,
  required DateTime generatedAt,
  String? paymentMode,
  double previousBalance = 0,
  double paymentsReceived = 0,
  double adjustments = 0,
  double amountDue = 0,
  // Placeholders (wire to real society data later).
  String? societyAddress,
  String? upiId,
  String? contactPhone,
  String? contactEmail,
  String? contactWebsite,
}) async {
  final money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final money2 =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final dFmt = DateFormat('d MMM yyyy');

  final baseFont =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Hind-Regular.ttf'));
  final boldFont =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Hind-SemiBold.ttf'));

  final isPaid = status.toUpperCase() == 'PAID';
  final invoiceNo = 'INV-${receiptNo.isNotEmpty ? receiptNo : '$year-$month'}';
  final periodStart = DateTime(year, month, 1);
  final periodEnd = DateTime(year, month + 1, 0);
  final billingPeriod = (month >= 1 && month <= 12)
      ? '${dFmt.format(periodStart)} – ${dFmt.format(periodEnd)}'
      : '—';

  // Breakup rows: per-home expense shares + reserve line, total = maintenance.
  final members = breakdown?.memberCount ?? 0;
  final hasSplit = breakdown != null && breakdown.hasData && members > 0;
  final billedTotal =
      hasSplit ? breakdown.perHomeExpected : amountPaid;
  final rows = <_Row>[];
  if (hasSplit) {
    for (var i = 0; i < breakdown.categories.length; i++) {
      final c = breakdown.categories[i];
      rows.add(_Row(
        color: _catPalette[i % _catPalette.length],
        name: c.name,
        desc: 'Your share of society ${c.name.toLowerCase()}',
        amount: c.perMember(members),
      ));
    }
    final reserve = breakdown.perHomeExpected - breakdown.perMemberTotal;
    if (reserve.abs() > 0.5) {
      rows.add(_Row(
        color: const PdfColor.fromInt(0xFF94A3B8),
        name: reserve >= 0 ? 'Society reserve' : 'From reserves',
        desc: reserve >= 0
            ? 'Contribution to common society reserves'
            : 'Shortfall covered from society reserves',
        amount: reserve,
      ));
    }
  } else {
    rows.add(_Row(
      color: _catPalette[0],
      name: 'Maintenance charges',
      desc: 'Monthly maintenance for the society',
      amount: billedTotal,
    ));
  }

  final addr = societyAddress ?? '[Society address — to be added]';
  final upi = upiId ?? '[society-upi-id@bank]';
  final phone = contactPhone ?? '[+91 00000 00000]';
  final email = contactEmail ?? '[admin@society.example]';
  final web = contactWebsite ?? '[www.society.example]';

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 20),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      build: (ctx) {
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.max,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(societyName, addr, invoiceNo, dFmt, paidAt, generatedAt,
                periodEnd),
            pw.Divider(color: _line, height: 22),
            _billToAndDetails(residentName, villaLabel, societyName, addr,
                invoiceNo, billingPeriod, isPaid, isPaid ? paymentMode : null),
            pw.SizedBox(height: 18),
            _breakupCard(rows, billedTotal, money),
            pw.SizedBox(height: 14),
            _summaryAndScan(previousBalance, paymentsReceived, adjustments,
                isPaid ? 0 : amountDue, money2, upi),
            pw.SizedBox(height: 16),
            _termsAndSign(societyName),
            pw.Spacer(),
            _footer(phone, email, web),
          ],
        );
      },
    ),
  );

  return doc.save();
}

// ============================================================
// Sections
// ============================================================

pw.Widget _header(
  String society,
  String addr,
  String invoiceNo,
  DateFormat dFmt,
  DateTime? paidAt,
  DateTime generatedAt,
  DateTime dueDate,
) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Logo placeholder + society identity.
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 38,
                  height: 38,
                  decoration: pw.BoxDecoration(
                    color: _green,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text('GG',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    society,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(addr, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
      ),
      // INVOICE + number + dates.
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('INVOICE',
              style: pw.TextStyle(
                  fontSize: 26, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('# $invoiceNo',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Date of Invoice :  ${dFmt.format(paidAt ?? generatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: _ink)),
          pw.SizedBox(height: 2),
          pw.Text('Due Date :  ${dFmt.format(dueDate)}',
              style: const pw.TextStyle(fontSize: 9, color: _ink)),
        ],
      ),
    ],
  );
}

pw.Widget _billToAndDetails(
  String name,
  String unit,
  String society,
  String addr,
  String invoiceNo,
  String billingPeriod,
  bool isPaid,
  String? paymentMode,
) {
  pw.Widget detail(String k, String v, {PdfColor? valueColor}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          children: [
            pw.SizedBox(
                width: 88,
                child: pw.Text(k,
                    style: const pw.TextStyle(fontSize: 9.5, color: _muted))),
            pw.Text(':  ', style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
            pw.Expanded(
              child: pw.Text(v,
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      color: valueColor ?? _ink,
                      fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      );

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BILL TO',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 8),
            pw.Text(unit.isNotEmpty ? unit : 'Your unit',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 2),
            if (name.isNotEmpty)
              pw.Text(name, style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
            pw.Text(society, style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
            pw.Text(addr, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
      ),
      pw.SizedBox(width: 24),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INVOICE DETAILS',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 8),
            detail('Invoice No.', invoiceNo),
            detail('Billing Period', billingPeriod),
            detail('Unit / Flat', unit.isNotEmpty ? unit : '—'),
            detail('Type', 'Maintenance Invoice'),
            detail('Status', isPaid ? 'Paid' : 'Unpaid',
                valueColor: isPaid ? _green : _red),
            if (paymentMode != null && paymentMode.isNotEmpty)
              detail('Paid via', paymentMode),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _breakupCard(List<_Row> rows, double total, NumberFormat money) {
  pw.Widget cell(String text,
          {required int flex,
          pw.Alignment align = pw.Alignment.centerLeft,
          PdfColor color = _ink,
          bool bold = false,
          double size = 9.5}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          alignment: align,
          child: pw.Text(text,
              textAlign:
                  align == pw.Alignment.centerRight ? pw.TextAlign.right : null,
              style: pw.TextStyle(
                  fontSize: size,
                  color: color,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      );

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    padding: const pw.EdgeInsets.all(14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('INVOICE BREAKUP',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
        pw.SizedBox(height: 10),
        // header
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Row(children: [
            cell('#', flex: 1, color: PdfColors.white, bold: true),
            cell('Particulars', flex: 6, color: PdfColors.white, bold: true),
            cell('Description', flex: 9, color: PdfColors.white, bold: true),
            cell('Amount (₹)',
                flex: 5,
                align: pw.Alignment.centerRight,
                color: PdfColors.white,
                bold: true),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                cell('${i + 1}', flex: 1),
                pw.Expanded(
                  flex: 6,
                  child: pw.Row(children: [
                    pw.Container(
                        width: 8,
                        height: 8,
                        decoration: pw.BoxDecoration(
                            color: rows[i].color, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(rows[i].name,
                          style: pw.TextStyle(
                              fontSize: 9.5,
                              color: _ink,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ]),
                ),
                cell(rows[i].desc, flex: 9, color: _muted),
                cell(money.format(rows[i].amount).replaceAll('₹', ''),
                    flex: 5, align: pw.Alignment.centerRight),
              ],
            ),
          ),
        // total
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _navySoft,
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(4),
              bottomRight: pw.Radius.circular(4),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: pw.Row(children: [
            cell('TOTAL AMOUNT',
                flex: 16, color: _navy, bold: true, size: 11),
            cell(money.format(total), flex: 5,
                align: pw.Alignment.centerRight, color: _navy, bold: true, size: 12),
          ]),
        ),
      ],
    ),
  );
}

pw.Widget _summaryAndScan(
  double prevBalance,
  double received,
  double adjustments,
  double amountDue,
  NumberFormat money,
  String upi,
) {
  pw.Widget sumRow(String k, String v, {PdfColor color = _ink}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 9.5, color: color, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Payment summary
      pw.Expanded(
        flex: 11,
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          padding: const pw.EdgeInsets.all(14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('PAYMENT SUMMARY',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
              pw.Divider(color: _line, height: 14),
              sumRow('Previous Balance', money.format(prevBalance)),
              sumRow('Payments Received', '- ${money.format(received)}',
                  color: _red),
              sumRow('Adjustments / Credits', '- ${money.format(adjustments)}',
                  color: _red),
              pw.SizedBox(height: 6),
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: _greenSoft,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AMOUNT DUE',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _green)),
                    pw.Text(money.format(amountDue),
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: _green)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 14),
      // Scan & pay
      pw.Expanded(
        flex: 12,
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          padding: const pw.EdgeInsets.all(14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SCAN & PAY',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // QR placeholder
                  pw.Container(
                    width: 86,
                    height: 86,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _line),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('QR\nplaceholder',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8, color: _muted)),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('UPI ID:',
                            style: const pw.TextStyle(fontSize: 9, color: _muted)),
                        pw.Text(upi,
                            style: pw.TextStyle(
                                fontSize: 9.5,
                                color: _ink,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('or pay via',
                            style: const pw.TextStyle(fontSize: 9, color: _muted)),
                        pw.SizedBox(height: 4),
                        pw.Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: ['GPay', 'PhonePe', 'Paytm', 'BHIM']
                              .map((p) => pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: _line),
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(p,
                                        style: const pw.TextStyle(
                                            fontSize: 8, color: _muted)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _termsAndSign(String society) {
  pw.Widget bullet(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('•  ', style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.Expanded(
                child: pw.Text(t,
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted))),
          ],
        ),
      );

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 13,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('TERMS & NOTES',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 8),
            bullet('Please pay the invoice amount before the due date to avoid late fees.'),
            bullet('In case of any discrepancy, please contact the management office.'),
            bullet('This is a computer-generated invoice.'),
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      // stamp + signature placeholders
      pw.Expanded(
        flex: 10,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 64,
              height: 64,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: _line),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('STAMP',
                  style: const pw.TextStyle(fontSize: 7, color: _muted)),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('For $society',
                      style: pw.TextStyle(
                          fontSize: 9.5,
                          color: _ink,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 26),
                  pw.Container(height: 0.7, color: _line),
                  pw.SizedBox(height: 3),
                  pw.Text('Authorised Signatory',
                      style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _footer(String phone, String email, String web) {
  pw.Widget item(String t) =>
      pw.Text(t, style: const pw.TextStyle(fontSize: 8.5, color: _muted));
  return pw.Column(children: [
    pw.Divider(color: _line, height: 14),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [item(phone), item(email), item(web)],
    ),
  ]);
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
