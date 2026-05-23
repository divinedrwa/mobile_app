/// Models for the Special Projects feature.

class SpecialProjectModel {
  final String id;
  final String title;
  final String? description;
  final String type;
  final String status;
  final double targetAmount;
  final double totalCollected;
  final double totalExpenses;
  final DateTime createdAt;
  final String? createdByName;
  final int contributionCount;
  final int expenseCount;
  final ProjectContributionModel? myContribution;

  const SpecialProjectModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.status,
    required this.targetAmount,
    required this.totalCollected,
    required this.totalExpenses,
    required this.createdAt,
    this.createdByName,
    this.contributionCount = 0,
    this.expenseCount = 0,
    this.myContribution,
  });

  double get balance => totalCollected - totalExpenses;
  double get outstanding => targetAmount - totalCollected;
  int get collectionPercent =>
      targetAmount > 0 ? ((totalCollected / targetAmount) * 100).round() : 0;

  factory SpecialProjectModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    final myContrib = json['myContribution'] as Map<String, dynamic>?;

    return SpecialProjectModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'OTHER',
      status: json['status'] as String? ?? 'ACTIVE',
      targetAmount: _toDouble(json['targetAmount']),
      totalCollected: _toDouble(json['totalCollected']),
      totalExpenses: _toDouble(json['totalExpenses']),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      createdByName: createdBy?['name'] as String?,
      contributionCount: count?['contributions'] as int? ?? 0,
      expenseCount: count?['expenses'] as int? ?? 0,
      myContribution: myContrib != null
          ? ProjectContributionModel.fromJson(myContrib)
          : null,
    );
  }
}

class ProjectContributionModel {
  final String id;
  final double amount;
  final double paidAmount;
  final String status;
  final DateTime? dueDate;
  final String? villaNumber;
  final String? ownerName;
  final List<ProjectPaymentModel> payments;

  const ProjectContributionModel({
    required this.id,
    required this.amount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
    this.villaNumber,
    this.ownerName,
    this.payments = const [],
  });

  double get outstanding => amount - paidAmount;

  factory ProjectContributionModel.fromJson(Map<String, dynamic> json) {
    final villa = json['villa'] as Map<String, dynamic>?;
    final paymentsList = json['payments'] as List?;

    return ProjectContributionModel(
      id: json['id'] as String? ?? '',
      amount: _toDouble(json['amount']),
      paidAmount: _toDouble(json['paidAmount']),
      status: json['status'] as String? ?? 'UNPAID',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      villaNumber: villa?['villaNumber'] as String?,
      ownerName: villa?['ownerName'] as String?,
      payments: paymentsList
              ?.whereType<Map>()
              .map((p) =>
                  ProjectPaymentModel.fromJson(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
    );
  }
}

class ProjectPaymentModel {
  final String id;
  final double amount;
  final String method;
  final String? reference;
  final DateTime paidAt;

  const ProjectPaymentModel({
    required this.id,
    required this.amount,
    required this.method,
    this.reference,
    required this.paidAt,
  });

  factory ProjectPaymentModel.fromJson(Map<String, dynamic> json) {
    return ProjectPaymentModel(
      id: json['id'] as String? ?? '',
      amount: _toDouble(json['amount']),
      method: json['method'] as String? ?? 'CASH',
      reference: json['reference'] as String?,
      paidAt: DateTime.tryParse(json['paidAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ProjectExpenseModel {
  final String id;
  final String description;
  final double amount;
  final String? vendor;
  final String? receiptUrl;
  final DateTime expenseDate;

  const ProjectExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    this.vendor,
    this.receiptUrl,
    required this.expenseDate,
  });

  factory ProjectExpenseModel.fromJson(Map<String, dynamic> json) {
    return ProjectExpenseModel(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: _toDouble(json['amount']),
      vendor: json['vendor'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      expenseDate:
          DateTime.tryParse(json['expenseDate'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
