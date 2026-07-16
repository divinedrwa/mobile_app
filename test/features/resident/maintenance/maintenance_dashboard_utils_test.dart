import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/providers/maintenance_provider.dart';
import 'package:divine_app/features/resident/data/utils/billing_cycle_visibility.dart';
import 'package:divine_app/features/resident/presentation/pages/maintenance/dashboard/maintenance_dashboard_utils.dart';

void main() {
  group('normalizeDashboardPayload', () {
    test('unwraps nested data envelope', () {
      final raw = {
        'data': {'summary': {'total': 100}},
        'meta': 'ignored',
      };
      final out = normalizeDashboardPayload(raw);
      expect(out['summary'], {'total': 100});
      expect(out.containsKey('meta'), isFalse);
    });

    test('returns root when no data key', () {
      final raw = {'residents': <dynamic>[]};
      expect(normalizeDashboardPayload(raw), same(raw));
    });
  });

  group('monthYearFromCycleKey', () {
    test('parses YYYY-MM cycle keys', () {
      expect(monthYearFromCycleKey('2026-07'), (month: 7, year: 2026));
    });

    test('rejects invalid keys', () {
      expect(monthYearFromCycleKey('2026-13'), isNull);
      expect(monthYearFromCycleKey('bad'), isNull);
    });
  });

  group('pickDefaultBillingCycleId', () {
    test('ignores UPCOMING and draft cycles', () {
      final id = pickDefaultBillingCycleId([
        {'id': 'draft', 'cycleKey': '2026-07', 'status': 'UPCOMING'},
        {'id': 'open', 'cycleKey': '2026-06', 'status': 'OPEN', 'publishedAt': '2026-06-01'},
      ]);
      expect(id, 'open');
    });

    test('prefers OPEN cycle over matching calendar month UPCOMING', () {
      final now = DateTime.now();
      final key =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final id = pickDefaultBillingCycleId([
        {'id': 'a', 'cycleKey': '2020-01', 'status': 'CLOSED', 'publishedAt': '2020-01-01'},
        {'id': 'b', 'cycleKey': key, 'status': 'OPEN', 'publishedAt': '2026-01-01'},
      ]);
      expect(id, 'b');
    });

    test('falls back to last OPEN cycle', () {
      final id = pickDefaultBillingCycleId([
        {'id': 'closed', 'cycleKey': '2020-01', 'status': 'CLOSED', 'publishedAt': '2020-01-01'},
        {'id': 'open', 'cycleKey': '2020-02', 'status': 'OPEN', 'publishedAt': '2020-02-01'},
      ]);
      expect(id, 'open');
    });
  });

  group('pickDefaultFinancialYearId', () {
    test('selects FY containing today', () {
      final now = DateTime.now();
      final id = pickDefaultFinancialYearId([
        {
          'id': 'past',
          'startDate': '2000-01-01',
          'endDate': '2000-12-31',
        },
        {
          'id': 'current',
          'startDate':
              DateTime(now.year - 1, now.month, now.day).toIso8601String(),
          'endDate':
              DateTime(now.year + 1, now.month, now.day).toIso8601String(),
        },
      ]);
      expect(id, 'current');
    });
  });

  group('resolvedDashboardPeriod', () {
    test('uses filter from dashboard payload when present', () {
      const filter = MaintenanceDashboardFilter(month: 3, year: 2025);
      final period = resolvedDashboardPeriod(
        {'filter': {'month': 6, 'year': 2026}},
        filter,
      );
      expect(period.month, 6);
      expect(period.year, 2026);
    });

    test('falls back to UI filter', () {
      const filter = MaintenanceDashboardFilter(month: 4, year: 2024);
      final period = resolvedDashboardPeriod({}, filter);
      expect(period.month, 4);
      expect(period.year, 2024);
    });
  });
}
