/// Server-only billing window state (`GET /v1/cycles/current`).
///
/// Backend is the single source of truth — do not infer OPEN/CLOSED on device.
class BillingCycleStatus {
  const BillingCycleStatus._(this.value);

  final String value;

  static BillingCycleStatus? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    switch (raw.toUpperCase()) {
      case 'UPCOMING':
        return upcoming;
      case 'OPEN':
        return open;
      case 'CLOSED':
        return closed;
      default:
        return null;
    }
  }

  static const upcoming = BillingCycleStatus._('UPCOMING');
  static const open = BillingCycleStatus._('OPEN');
  static const closed = BillingCycleStatus._('CLOSED');

  bool get isUpcoming => value == upcoming.value;
  bool get isOpen => value == open.value;
  bool get isClosed => value == closed.value;
}

class BillingCycleCurrent {
  BillingCycleCurrent({
    this.cycleId,
    this.title,
    this.amount,
    this.totalDue,
    this.lateFee,
    this.effectiveLateFeeComponent,
    this.expectedAmount,
    this.paidAmount,
    this.deltaAmount,
    this.availableCredit,
    this.remainingDue,
    this.previousDue,
    this.status,
    this.paymentStartUtc,
    this.paymentEndUtc,
    this.dueDateUtc,
    this.isPaid = false,
    this.cycleKey,
    this.pendingDues = const [],
  });

  final String? cycleId;
  final String? title;
  final double? amount;
  final double? totalDue;
  final double? lateFee;
  final double? effectiveLateFeeComponent;
  final double? expectedAmount;
  final double? paidAmount;
  final double? deltaAmount;
  final double? availableCredit;
  final double? remainingDue;
  final double? previousDue;
  final BillingCycleStatus? status;
  final DateTime? paymentStartUtc;
  final DateTime? paymentEndUtc;
  /// Same as backend `dueDate` — typically payment window end (UTC ISO).
  final DateTime? dueDateUtc;
  final bool isPaid;
  final String? cycleKey;
  final List<BillingPendingDue> pendingDues;

  bool get hasCycle => cycleId != null && cycleId!.isNotEmpty;

  factory BillingCycleCurrent.fromJson(Map<String, dynamic> json) {
    double? dv(dynamic x) =>
        x == null ? null : (x is num ? x.toDouble() : double.tryParse(x.toString()));

    final statusRaw = json['status']?.toString();
    final pendingList = json['pendingDues'];
    final pendingDues = pendingList is List
        ? pendingList
            .whereType<Map>()
            .map((e) => BillingPendingDue.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <BillingPendingDue>[];
    return BillingCycleCurrent(
      cycleId: json['cycleId']?.toString(),
      title: json['title']?.toString(),
      amount: dv(json['amount']),
      totalDue: dv(json['totalDue']),
      lateFee: dv(json['lateFee']),
      effectiveLateFeeComponent: dv(json['effectiveLateFeeComponent']),
      expectedAmount: dv(json['expectedAmount']),
      paidAmount: dv(json['paidAmount']),
      deltaAmount: dv(json['deltaAmount']),
      availableCredit: dv(json['availableCredit']),
      remainingDue: dv(json['remainingDue']),
      previousDue: dv(json['previousDue']),
      status: BillingCycleStatus.tryParse(statusRaw),
      paymentStartUtc: DateTime.tryParse(json['paymentStartDate']?.toString() ?? ''),
      paymentEndUtc: DateTime.tryParse(json['paymentEndDate']?.toString() ?? ''),
      dueDateUtc: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
      isPaid: json['isPaid'] == true,
      cycleKey: json['cycleKey']?.toString(),
      pendingDues: pendingDues,
    );
  }

  BillingCycleCurrent copyWith({bool? isPaid}) => BillingCycleCurrent(
        cycleId: cycleId,
        title: title,
        amount: amount,
        totalDue: totalDue,
        lateFee: lateFee,
        effectiveLateFeeComponent: effectiveLateFeeComponent,
        expectedAmount: expectedAmount,
        paidAmount: paidAmount,
        deltaAmount: deltaAmount,
        availableCredit: availableCredit,
        remainingDue: remainingDue,
        previousDue: previousDue,
        status: status,
        paymentStartUtc: paymentStartUtc,
        paymentEndUtc: paymentEndUtc,
        dueDateUtc: dueDateUtc,
        isPaid: isPaid ?? this.isPaid,
        cycleKey: cycleKey,
        pendingDues: pendingDues,
      );
}

class BillingPendingDue {
  BillingPendingDue({
    required this.cycleId,
    required this.cycleKey,
    required this.title,
    required this.amount,
    this.paymentEndUtc,
    this.gracePeriodDays = 0,
    this.isGraceOver = false,
    this.status,
  });

  final String cycleId;
  final String cycleKey;
  final String title;
  final double amount;
  final DateTime? paymentEndUtc;
  final int gracePeriodDays;
  final bool isGraceOver;
  final BillingCycleStatus? status;

  factory BillingPendingDue.fromJson(Map<String, dynamic> json) {
    double dv(dynamic x) =>
        x == null ? 0 : (x is num ? x.toDouble() : double.tryParse(x.toString()) ?? 0);
    int iv(dynamic x) =>
        x == null ? 0 : (x is int ? x : int.tryParse(x.toString()) ?? 0);

    return BillingPendingDue(
      cycleId: json['cycleId']?.toString() ?? '',
      cycleKey: json['cycleKey']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: dv(json['amount']),
      paymentEndUtc: DateTime.tryParse(json['paymentEndDate']?.toString() ?? ''),
      gracePeriodDays: iv(json['gracePeriodDays']),
      isGraceOver: json['isGraceOver'] == true,
      status: BillingCycleStatus.tryParse(json['status']?.toString()),
    );
  }
}
