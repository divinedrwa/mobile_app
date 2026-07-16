import 'expense_model.dart';

enum ExpenseCyclePhase {
  draft,
  upcoming,
  open,
  closed,
  noCycle;

  static ExpenseCyclePhase fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'DRAFT':
        return ExpenseCyclePhase.draft;
      case 'UPCOMING':
        return ExpenseCyclePhase.upcoming;
      case 'OPEN':
        return ExpenseCyclePhase.open;
      case 'CLOSED':
        return ExpenseCyclePhase.closed;
      default:
        return ExpenseCyclePhase.noCycle;
    }
  }

  String get label {
    switch (this) {
      case ExpenseCyclePhase.draft:
        return 'Draft';
      case ExpenseCyclePhase.upcoming:
        return 'Upcoming';
      case ExpenseCyclePhase.open:
        return 'Open';
      case ExpenseCyclePhase.closed:
        return 'Closed';
      case ExpenseCyclePhase.noCycle:
        return 'No cycle';
    }
  }

  /// Resident-facing label — unpublished cycles are shown as upcoming, not draft.
  String get residentLabel {
    switch (this) {
      case ExpenseCyclePhase.draft:
      case ExpenseCyclePhase.upcoming:
        return 'Upcoming';
      case ExpenseCyclePhase.open:
        return 'Open';
      case ExpenseCyclePhase.closed:
        return 'Closed';
      case ExpenseCyclePhase.noCycle:
        return 'No cycle';
    }
  }

  bool get isEarlyCycle => this == ExpenseCyclePhase.draft || this == ExpenseCyclePhase.upcoming;
}

class ExpenseBillingCycleGroup {
  final String groupKey;
  final String? billingCycleId;
  final String? cycleKey;
  final String title;
  final ExpenseCyclePhase phase;
  final DateTime? publishedAt;
  final DateTime? paymentStartDate;
  final DateTime? paymentEndDate;
  final int month;
  final int year;
  final double totalAmount;
  final int expenseCount;
  final List<ExpenseModel> expenses;

  const ExpenseBillingCycleGroup({
    required this.groupKey,
    this.billingCycleId,
    this.cycleKey,
    required this.title,
    required this.phase,
    this.publishedAt,
    this.paymentStartDate,
    this.paymentEndDate,
    required this.month,
    required this.year,
    required this.totalAmount,
    required this.expenseCount,
    required this.expenses,
  });

  factory ExpenseBillingCycleGroup.fromJson(Map<String, dynamic> json) {
    final rawExpenses = json['expenses'] as List<dynamic>? ?? [];
    return ExpenseBillingCycleGroup(
      groupKey: json['groupKey'] as String? ?? '',
      billingCycleId: json['billingCycleId'] as String?,
      cycleKey: json['cycleKey'] as String?,
      title: json['title'] as String? ?? '',
      phase: ExpenseCyclePhase.fromApi(json['phase'] as String?),
      publishedAt: _parseDate(json['publishedAt']),
      paymentStartDate: _parseDate(json['paymentStartDate']),
      paymentEndDate: _parseDate(json['paymentEndDate']),
      month: json['month'] as int? ?? 0,
      year: json['year'] as int? ?? 0,
      totalAmount: _toDouble(json['totalAmount']),
      expenseCount: json['expenseCount'] as int? ?? rawExpenses.length,
      expenses: rawExpenses
          .map((e) =>
              ExpenseModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static double _toDouble(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}
