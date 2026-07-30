import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/models/visitor_model.dart';
import 'package:divine_app/features/resident/data/visitor_today_summary.dart';

VisitorModel _visitor({
  required String status,
  DateTime? checkInTime,
  DateTime? checkOutTime,
}) {
  return VisitorModel(
    name: 'Guest',
    phone: '9999999999',
    visitDate: checkInTime ?? DateTime(2026, 7, 30, 10),
    status: status,
    checkInTime: checkInTime,
    checkOutTime: checkOutTime,
  );
}

void main() {
  final now = DateTime(2026, 7, 30, 14);

  test('checked-out visitor counts as completed not inside', () {
    final summary = computeVisitorTodaySummary(
      [
        _visitor(
          status: 'CHECKED_OUT',
          checkInTime: DateTime(2026, 7, 30, 10),
          checkOutTime: DateTime(2026, 7, 30, 12),
        ),
      ],
      now: now,
    );

    expect(summary.total, 1);
    expect(summary.checkedIn, 0);
    expect(summary.checkedOut, 1);
  });

  test('walk-in checked in without checkout stays inside', () {
    final summary = computeVisitorTodaySummary(
      [
        _visitor(
          status: 'CHECKED_IN',
          checkInTime: DateTime(2026, 7, 30, 10),
        ),
      ],
      now: now,
    );

    expect(summary.total, 1);
    expect(summary.checkedIn, 1);
    expect(summary.checkedOut, 0);
  });

  test('pending approval walk-in is not inside or completed', () {
    final summary = computeVisitorTodaySummary(
      [
        _visitor(
          status: 'PENDING_APPROVAL',
          checkInTime: DateTime(2026, 7, 30, 10),
        ),
      ],
      now: now,
    );

    expect(summary.total, 1);
    expect(summary.checkedIn, 0);
    expect(summary.checkedOut, 0);
  });

  test('prefers API summary over partial history fallback', () {
    final resolved = resolveVisitorTodaySummary(
      apiSummary: (total: 3, checkedIn: 1, checkedOut: 2),
      history: [
        _visitor(
          status: 'CHECKED_IN',
          checkInTime: DateTime(2026, 7, 30, 10),
        ),
      ],
    );

    expect(resolved?.total, 3);
    expect(resolved?.checkedIn, 1);
    expect(resolved?.checkedOut, 2);
  });
}
