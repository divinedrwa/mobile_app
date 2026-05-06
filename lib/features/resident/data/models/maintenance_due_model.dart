class MaintenanceDueModel {
  final String id;
  final String villaId;
  final int month;
  final int year;
  final double amount;
  final DateTime dueDate;
  final String status;
  final DateTime? paidAt;
  final double? societyExpense;
  final Map<String, double> expenseBreakdown;

  MaintenanceDueModel({
    required this.id,
    required this.villaId,
    required this.month,
    required this.year,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.societyExpense,
    this.expenseBreakdown = const {},
  });

  factory MaintenanceDueModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;
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
      month: rawMonth is num ? rawMonth.toInt() : 0,
      year: rawYear is num ? rawYear.toInt() : 0,
      amount: amount,
      dueDate: DateTime.tryParse(
            json['dueDate']?.toString() ??
                json['paymentDueDate']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'PENDING',
      paidAt: DateTime.tryParse(
        json['paidAt']?.toString() ?? json['paymentDate']?.toString() ?? '',
      ),
      societyExpense: (json['societyExpense'] is num)
          ? (json['societyExpense'] as num).toDouble()
          : double.tryParse(json['societyExpense']?.toString() ?? ''),
      expenseBreakdown: breakdown,
    );
  }
}
