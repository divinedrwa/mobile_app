import 'dart:typed_data';

import 'package:divine_app/features/resident/data/models/expense_breakdown_model.dart';
import 'package:divine_app/features/resident/data/models/maintenance_due_model.dart';
import 'package:divine_app/features/resident/data/services/maintenance_invoice_pdf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MaintenanceDueModel due({String status = 'PENDING'}) => MaintenanceDueModel(
        id: 'due1',
        villaId: 'villa1',
        cycleId: 'c1',
        cycleKey: '2026-06',
        title: 'June 2026',
        month: 6,
        year: 2026,
        amount: 1100,
        expectedAmount: 1100,
        remainingDue: 900,
        dueDate: DateTime(2026, 6, 30),
        status: status,
      );

  ExpenseBreakdown breakdownWithCategories(int count) {
    final categories = List.generate(
      count,
      (i) => ExpenseCategory(name: 'Category ${i + 1}', amount: 1000 + i * 100),
    );
    return ExpenseBreakdown(
      month: 6,
      year: 2026,
      total: categories.fold<double>(0, (s, c) => s + c.amount),
      categories: categories,
      memberCount: 10,
      expenseDivisor: 10,
      totalExpected: 11000,
      residentExpectedAmount: 1100,
    );
  }

  int pdfPageCount(Uint8List bytes) {
    final text = String.fromCharCodes(bytes);
    return RegExp(r'/Type\s*/Page(?!s)').allMatches(text).length;
  }

  test('invoice cache filename is unique per logged-in user', () {
    final m = due();
    final a = invoiceCacheFilename(m, userId: 'user_a_123');
    final b = invoiceCacheFilename(m, userId: 'user_b_456');
    expect(a, isNot(equals(b)));
    expect(a, contains('user_a_123'));
    expect(b, contains('user_b_456'));
  });

  test('invoice cache filename differs for PAID vs DUE', () {
    final pending = due(status: 'PARTIAL');
    final paid = due(status: 'PAID');
    final a = invoiceCacheFilename(pending, userId: 'u1');
    final b = invoiceCacheFilename(paid, userId: 'u1');
    expect(a, contains('_DUE_'));
    expect(b, contains('_PAID_'));
    expect(a, isNot(equals(b)));
  });

  test('invoice cache filename falls back to villa when user id missing', () {
    final m = due();
    final name = invoiceCacheFilename(m, villaId: 'villa_xyz');
    expect(name, contains('villa_villa_xyz'));
  });

  test('density escalates when breakup rows and pay block grow', () {
    expect(
      invoicePdfDensityForContent(
        rowCount: 5,
        showPay: false,
        hasLongAddress: false,
      ),
      InvoicePdfDensity.standard,
    );
    expect(
      invoicePdfDensityForContent(
        rowCount: 9,
        showPay: true,
        hasLongAddress: false,
      ),
      InvoicePdfDensity.compact,
    );
    expect(
      invoicePdfDensityForContent(
        rowCount: 12,
        showPay: true,
        hasLongAddress: true,
      ),
      InvoicePdfDensity.dense,
    );
  });

  test('invoice PDF stays on one page with many breakup rows', () async {
    final bytes = await buildMaintenanceInvoicePdf(
      societyName: 'Divine Residency',
      societyAddress: 'Sector 62, Noida, Uttar Pradesh',
      residentName: 'Test Resident',
      villaLabel: 'A-09',
      month: 6,
      year: 2026,
      receiptNo: 'INV-2026-06',
      billedAmount: 1100,
      paidAt: null,
      status: 'PENDING',
      breakdown: breakdownWithCategories(14),
      generatedAt: DateTime(2026, 6, 15),
      amountDue: 1100,
      upiId: 'society@upi',
      payeeName: 'Divine Residency',
    );
    expect(bytes, isNotEmpty);
    expect(pdfPageCount(bytes), 1);
  });
}
