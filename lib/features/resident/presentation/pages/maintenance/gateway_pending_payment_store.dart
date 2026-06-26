import 'dart:convert';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/storage_service.dart';

/// Locally persisted in-flight gateway checkout (survives app kill / force-close).
class GatewayPendingPayment {
  const GatewayPendingPayment({
    required this.transactionId,
    required this.gateway,
    required this.amount,
    required this.userId,
    required this.savedAtMs,
    this.periodLabel,
    this.payAllPending = false,
    this.platformFee = 0,
    this.platformFeeGst = 0,
    this.totalPaid = 0,
    this.paymentMethod = 'Razorpay',
  });

  final String transactionId;
  /// `razorpay` or `phonepe`
  final String gateway;
  final double amount;
  final String? periodLabel;
  final bool payAllPending;
  final double platformFee;
  final double platformFeeGst;
  final double totalPaid;
  final String paymentMethod;
  final String userId;
  final int savedAtMs;

  static const maxAgeMs = 7 * 24 * 60 * 60 * 1000;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - savedAtMs > maxAgeMs;

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'gateway': gateway,
        'amount': amount,
        if (periodLabel != null) 'periodLabel': periodLabel,
        'payAllPending': payAllPending,
        'platformFee': platformFee,
        'platformFeeGst': platformFeeGst,
        'totalPaid': totalPaid,
        'paymentMethod': paymentMethod,
        'userId': userId,
        'savedAtMs': savedAtMs,
      };

  factory GatewayPendingPayment.fromJson(Map<String, dynamic> json) {
    return GatewayPendingPayment(
      transactionId: json['transactionId']?.toString() ?? '',
      gateway: json['gateway']?.toString() ?? 'razorpay',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      periodLabel: json['periodLabel']?.toString(),
      payAllPending: json['payAllPending'] == true,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0,
      platformFeeGst: (json['platformFeeGst'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'Razorpay',
      userId: json['userId']?.toString() ?? '',
      savedAtMs: (json['savedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Persists the active gateway order id until payment is confirmed or abandoned.
class GatewayPendingPaymentStore {
  GatewayPendingPaymentStore._();

  static const _storageKey = 'gateway_pending_payment_v1';

  static GatewayPendingPayment? read() {
    final raw = StorageService.prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final pending = GatewayPendingPayment.fromJson(json);
      if (pending.transactionId.isEmpty) return null;
      return pending;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(GatewayPendingPayment pending) async {
    await StorageService.prefs.setString(
      _storageKey,
      jsonEncode(pending.toJson()),
    );
  }

  static Future<void> clear() async {
    await StorageService.prefs.remove(_storageKey);
  }

  static Future<void> saveForUser({
    required String userId,
    required String transactionId,
    required String gateway,
    required double amount,
    String? periodLabel,
    bool payAllPending = false,
    double platformFee = 0,
    double platformFeeGst = 0,
    double totalPaid = 0,
    String paymentMethod = 'Razorpay',
  }) async {
    await save(
      GatewayPendingPayment(
        transactionId: transactionId,
        gateway: gateway,
        amount: amount,
        periodLabel: periodLabel,
        payAllPending: payAllPending,
        platformFee: platformFee,
        platformFeeGst: platformFeeGst,
        totalPaid: totalPaid > 0 ? totalPaid : amount,
        paymentMethod: paymentMethod,
        userId: userId,
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static String? currentUserId() =>
      StorageService.prefs.getString(AppConstants.keyUserId);
}
