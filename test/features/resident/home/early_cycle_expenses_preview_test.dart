import 'package:divine_app/features/resident/data/models/early_cycle_expenses_preview.dart';
import 'package:divine_app/features/resident/data/models/expense_billing_cycle_group.dart';
import 'package:divine_app/features/resident/data/models/resident_dashboard_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EarlyCycleExpensesPreview parses draft cycle payload', () {
    final preview = EarlyCycleExpensesPreview.tryFromJson({
      'billingCycleId': 'c1',
      'cycleKey': '2026-07',
      'title': 'July 2026 Maintenance',
      'phase': 'DRAFT',
      'month': 7,
      'year': 2026,
      'totalAmount': 15189,
      'expenseCount': 12,
      'paymentStartDate': '2026-08-01T00:00:00.000Z',
    });

    expect(preview, isNotNull);
    expect(preview!.phase, ExpenseCyclePhase.draft);
    expect(preview.phaseLabel, 'Upcoming');
    expect(preview.totalAmount, 15189);
    expect(preview.itemLabel, '12 items');
  });

  test('ExpenseCyclePhase residentLabel maps draft to Upcoming', () {
    expect(ExpenseCyclePhase.draft.residentLabel, 'Upcoming');
    expect(ExpenseCyclePhase.upcoming.residentLabel, 'Upcoming');
    expect(ExpenseCyclePhase.open.residentLabel, 'Open');
  });

  test('EarlyCycleExpensesPreview rejects open cycles', () {
    final preview = EarlyCycleExpensesPreview.tryFromJson({
      'cycleKey': '2026-06',
      'title': 'June 2026',
      'phase': 'OPEN',
      'month': 6,
      'year': 2026,
      'totalAmount': 1000,
      'expenseCount': 2,
    });
    expect(preview, isNull);
  });

  test('ResidentFundSnapshot parses earlyCycleExpenses from dashboard fund', () {
    final fund = ResidentFundSnapshot.fromJson({
      'currentBalance': 1000,
      'allTimeCollected': 5000,
      'allTimeSpent': 4000,
      'month': 7,
      'year': 2026,
      'monthCollected': 100,
      'monthSpent': 50,
      'monthNet': 50,
      'additionalMergedInflowMonth': 0,
      'additionalMergedInflowAllTime': 0,
      'totalAdvanceCredit': 0,
      'expectedAllTime': 6000,
      'pendingDues': 200,
      'projectedBalance': 1200,
      'collectionRate': 80,
      'earlyCycleExpenses': {
        'cycleKey': '2026-07',
        'title': 'July 2026',
        'phase': 'UPCOMING',
        'month': 7,
        'year': 2026,
        'totalAmount': 5000,
        'expenseCount': 4,
      },
    });

    expect(fund.earlyCycleExpenses, isNotNull);
    expect(fund.earlyCycleExpenses!.phase, ExpenseCyclePhase.upcoming);
  });
}
