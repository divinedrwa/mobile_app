import 'expense_billing_cycle_group.dart';

/// Preview of approved expenses recorded against a draft or upcoming billing cycle.
/// Returned from `GET /residents/dashboard` → `fund.earlyCycleExpenses`.
class EarlyCycleExpensesPreview {
  const EarlyCycleExpensesPreview({
    this.billingCycleId,
    required this.cycleKey,
    required this.title,
    required this.phase,
    required this.month,
    required this.year,
    required this.totalAmount,
    required this.expenseCount,
    this.paymentStartDate,
  });

  final String? billingCycleId;
  final String cycleKey;
  final String title;
  final ExpenseCyclePhase phase;
  final int month;
  final int year;
  final double totalAmount;
  final int expenseCount;
  final DateTime? paymentStartDate;

  bool get hasExpenses => expenseCount > 0;

  bool get isDraft => phase == ExpenseCyclePhase.draft;

  bool get isUpcoming => phase == ExpenseCyclePhase.upcoming;

  String get phaseLabel => phase.residentLabel;

  String get subtitle {
    if (isDraft || isUpcoming) {
      return 'Early spending before the payment window opens';
    }
    return 'Approved society spending for this cycle';
  }

  String get itemLabel => expenseCount == 1 ? '1 item' : '$expenseCount items';

  factory EarlyCycleExpensesPreview.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('earlyCycleExpenses payload is null');
    }
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    int iv(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return EarlyCycleExpensesPreview(
      billingCycleId: json['billingCycleId'] as String?,
      cycleKey: json['cycleKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      phase: ExpenseCyclePhase.fromApi(json['phase'] as String?),
      month: iv(json['month']),
      year: iv(json['year']),
      totalAmount: d(json['totalAmount']),
      expenseCount: iv(json['expenseCount']),
      paymentStartDate: json['paymentStartDate'] != null
          ? DateTime.tryParse(json['paymentStartDate'].toString())
          : null,
    );
  }

  static EarlyCycleExpensesPreview? tryFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      final preview = EarlyCycleExpensesPreview.fromJson(json);
      if (!preview.hasExpenses || preview.month < 1 || preview.year < 1) {
        return null;
      }
      if (preview.phase != ExpenseCyclePhase.draft &&
          preview.phase != ExpenseCyclePhase.upcoming) {
        return null;
      }
      return preview;
    } catch (_) {
      return null;
    }
  }
}
