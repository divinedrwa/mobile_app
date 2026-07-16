import 'package:divine_app/features/resident/data/models/maintenance_due_model.dart';
import 'package:divine_app/features/resident/data/services/maintenance_invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
