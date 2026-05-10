class MaintenanceDueModel {
  final String id;
  final String villaId;
  final String cycleId;
  final String cycleKey;
  final String title;
  final int month;
  final int year;
  final double amount;
  final DateTime dueDate;
  final String status;
  final DateTime? paidAt;
  final double expectedAmount;
  final double paidAmount;
  final double cashPaidAmount;
  final double creditApplied;
  final double remainingDue;
  final double previousDue;
  final double carryForwardBalance;
  final bool isOverdue;
  final double? societyExpense;
  final Map<String, double> expenseBreakdown;

  MaintenanceDueModel({
    required this.id,
    required this.villaId,
    this.cycleId = '',
    this.cycleKey = '',
    this.title = '',
    required this.month,
    required this.year,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.expectedAmount = 0,
    this.paidAmount = 0,
    this.cashPaidAmount = 0,
    this.creditApplied = 0,
    this.remainingDue = 0,
    this.previousDue = 0,
    this.carryForwardBalance = 0,
    this.isOverdue = false,
    this.societyExpense,
    this.expenseBreakdown = const {},
  });

  factory MaintenanceDueModel.fromJson(Map<String, dynamic> json) {
    double dv(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    final amount = dv(json['amount']);
    final rawMonth = json['month'] ?? json['maintenanceMonth'];
    final rawYear = json['year'] ?? json['maintenanceYear'];

    final breakdownRaw = json['expenseBreakdown'];
    final Map<String, double> breakdown = {};
    if (breakdownRaw is Map) {
      for (final entry in breakdownRaw.entries) {
        final value = entry.value;
        final parsed = value is num
            ? value.toDouble()
            : double.tryParse(value?.toString() ?? '');
        if (parsed != null) {
          breakdown[entry.key.toString()] = parsed;
        }
      }
    }

    return MaintenanceDueModel(
      id: json['id']?.toString() ?? '',
      villaId: json['villaId']?.toString() ?? '',
      cycleId: json['cycleId']?.toString() ?? '',
      cycleKey: json['cycleKey']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      month: rawMonth is num ? rawMonth.toInt() : 0,
      year: rawYear is num ? rawYear.toInt() : 0,
      amount: amount,
      dueDate:
          DateTime.tryParse(
            json['dueDate']?.toString() ??
                json['paymentDueDate']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'PENDING',
      paidAt: DateTime.tryParse(
        json['paidAt']?.toString() ?? json['paymentDate']?.toString() ?? '',
      ),
      expectedAmount: dv(json['expectedAmount']),
      paidAmount: dv(json['paidAmount']),
      cashPaidAmount: dv(json['cashPaidAmount']),
      creditApplied: dv(json['creditApplied']),
      remainingDue: dv(json['remainingDue']),
      previousDue: dv(json['previousDue']),
      carryForwardBalance: dv(json['carryForwardBalance']),
      isOverdue: json['isOverdue'] == true,
      societyExpense: (json['societyExpense'] is num)
          ? (json['societyExpense'] as num).toDouble()
          : double.tryParse(json['societyExpense']?.toString() ?? ''),
      expenseBreakdown: breakdown,
    );
  }
}
