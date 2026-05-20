class UpiPaymentModel {
  final String id;
  final String userId;
  final String villaId;
  final String? villaNumber;
  final String? userName;
  final String? cycleId;
  final double amount;
  final String? upiTransactionRef;
  final String status;
  final DateTime submittedAt;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? remark;
  final int month;
  final int year;

  UpiPaymentModel({
    required this.id,
    required this.userId,
    required this.villaId,
    this.villaNumber,
    this.userName,
    this.cycleId,
    required this.amount,
    this.upiTransactionRef,
    required this.status,
    required this.submittedAt,
    this.verifiedAt,
    this.rejectionReason,
    this.remark,
    required this.month,
    required this.year,
  });

  factory UpiPaymentModel.fromJson(Map<String, dynamic> json) {
    double dv(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    // Nested user / villa from admin listing
    final user = json['user'] as Map<String, dynamic>?;
    final villa = json['villa'] as Map<String, dynamic>?;

    return UpiPaymentModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      villaId: json['villaId']?.toString() ?? '',
      villaNumber: villa?['villaNumber']?.toString() ?? json['villaNumber']?.toString(),
      userName: user?['name']?.toString() ?? json['userName']?.toString(),
      cycleId: json['cycleId']?.toString(),
      amount: dv(json['amount']),
      upiTransactionRef: json['upiTransactionRef']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
          DateTime.now(),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'].toString())
          : null,
      rejectionReason: json['rejectionReason']?.toString(),
      remark: json['remark']?.toString(),
      month: json['month'] is num ? (json['month'] as num).toInt() : 0,
      year: json['year'] is num ? (json['year'] as num).toInt() : 0,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isVerified => status == 'VERIFIED';
  bool get isRejected => status == 'REJECTED';
}
