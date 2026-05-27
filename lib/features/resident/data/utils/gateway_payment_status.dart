/// Parsed response from `GET /v1/payments/phonepe/status/:id` or
/// `GET /v1/payments/razorpay/status/:orderId`.
class GatewayPaymentPollResult {
  const GatewayPaymentPollResult({
    required this.status,
    required this.outcome,
    this.detail,
    this.gatewayAvailable = true,
    this.reconciled = false,
    this.ledgerSynced = false,
    this.rawGatewayState,
    this.rawGatewayCode,
  });

  final String status;
  final String outcome;
  final String? detail;
  final bool gatewayAvailable;
  final bool reconciled;
  /// Maintenance ledger + snapshot updated (admin grid / resident dues).
  final bool ledgerSynced;
  final String? rawGatewayState;
  final String? rawGatewayCode;

  factory GatewayPaymentPollResult.fromJson(Map<String, dynamic> json) {
    return GatewayPaymentPollResult(
      status: json['status']?.toString() ?? 'UNKNOWN',
      outcome: json['outcome']?.toString() ?? '',
      detail: json['detail']?.toString(),
      gatewayAvailable:
          json['phonepeAvailable'] as bool? ??
          json['razorpayAvailable'] as bool? ??
          true,
      reconciled: json['reconciled'] == true,
      ledgerSynced: json['ledgerSynced'] == true,
      rawGatewayState:
          json['phonepeState']?.toString() ?? json['razorpayState']?.toString(),
      rawGatewayCode:
          json['phonepeCode']?.toString() ?? json['razorpayCode']?.toString(),
    );
  }

  factory GatewayPaymentPollResult.empty() {
    return const GatewayPaymentPollResult(
      status: 'UNKNOWN',
      outcome: 'unknown',
      gatewayAvailable: false,
      detail: 'Empty response from server',
    );
  }

  /// Server recorded payment on billing AND maintenance ledger (admin + resident).
  bool get isRecordedOrCompleted =>
      ledgerSynced &&
      (outcome == 'completed' ||
          outcome == 'recorded' ||
          (status == 'SUCCESS' && outcome != 'reconcile_failed'));

  bool get isFailed =>
      status == 'FAILED' ||
      outcome == 'failed' ||
      rawGatewayState == 'FAILED' ||
      rawGatewayState == 'PAYMENT_ERROR';

  bool get isPending => outcome == 'pending' || status == 'PENDING';

  bool get isGatewayUnavailable =>
      outcome == 'gateway_unavailable' && !gatewayAvailable;

  bool get isReconcileFailed => outcome == 'reconcile_failed';

  String get failureMessage =>
      (detail != null && detail!.isNotEmpty)
          ? detail!
          : 'Payment failed. Please try again.';
}
