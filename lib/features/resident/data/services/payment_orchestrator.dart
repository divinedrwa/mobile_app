/// B2 — Unified payment orchestrator for Razorpay, PhonePe, UPI, and credit-only paths.
///
/// Single entry point for poll handling, pending persistence, recovery, and navigation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_navigator_keys.dart';
import '../providers/maintenance_provider.dart';
import '../repositories/maintenance_repository.dart';
import '../utils/gateway_payment_status.dart';
import '../../presentation/pages/maintenance/gateway_payment_poll_actions.dart';
import '../../presentation/pages/maintenance/gateway_payment_recovery.dart';
import '../../presentation/pages/maintenance/gateway_pending_payment_store.dart';

export '../utils/gateway_payment_status.dart' show GatewayPaymentPollResult;
export '../../presentation/pages/maintenance/gateway_pending_payment_store.dart'
    show GatewayPendingPayment, GatewayPendingPaymentStore;

class PaymentOrchestrator {
  PaymentOrchestrator._();

  /// True when create-order response settles via advance credit (no SDK checkout).
  static bool isCreditOnlyCheckout(Map<String, dynamic> createOrderResponse) {
    final orderId = createOrderResponse['orderId'];
    final autoSettled = createOrderResponse['autoSettledFromCredit'] == true;
    final amountPaise = createOrderResponse['amountPaise'];
    final zeroAmount = amountPaise == 0 || amountPaise == 0.0;
    return (orderId == null || orderId == '') && (autoSettled || zeroAmount);
  }

  static Future<void> persistPending({
    required String transactionId,
    required String gateway,
    required double amount,
    String? periodLabel,
    bool payAllPending = false,
    double platformFee = 0,
    double platformFeeGst = 0,
    double totalPaid = 0,
    String paymentMethod = 'Razorpay',
  }) =>
      GatewayPaymentPollActions.persistPendingGatewayPayment(
        transactionId: transactionId,
        gateway: gateway,
        amount: amount,
        periodLabel: periodLabel,
        payAllPending: payAllPending,
        platformFee: platformFee,
        platformFeeGst: platformFeeGst,
        totalPaid: totalPaid,
        paymentMethod: paymentMethod,
      );

  static Future<void> clearPending() =>
      GatewayPaymentPollActions.clearPersistedGatewayPayment();

  static bool handlePollResult({
    required GatewayPaymentPollResult poll,
    required VoidCallback onSuccess,
    required void Function(String message) onFailed,
    required void Function(String message) onGatewayUnavailable,
  }) =>
      GatewayPaymentPollActions.handlePollResult(
        poll: poll,
        onSuccess: onSuccess,
        onFailed: onFailed,
        onGatewayUnavailable: onGatewayUnavailable,
      );

  static void navigateToPending(
    BuildContext context, {
    required String transactionId,
    required String paymentMethod,
    required String gateway,
    required double amount,
    String? periodLabel,
    bool payAllPending = false,
    double platformFee = 0,
    double platformFeeGst = 0,
    double totalPaid = 0,
  }) =>
      GatewayPaymentPollActions.navigateToPaymentPending(
        context,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
        gateway: gateway,
        amount: amount,
        periodLabel: periodLabel,
        payAllPending: payAllPending,
        platformFee: platformFee,
        platformFeeGst: platformFeeGst,
        totalPaid: totalPaid,
      );

  static void navigateToSuccess(
    BuildContext context, {
    required double maintenanceAmount,
    required double totalPaid,
    required String paymentMethod,
    required String periodLabel,
    required String transactionId,
    bool payAllPending = false,
    double platformFee = 0,
    double platformFeeGst = 0,
  }) =>
      GatewayPaymentPollActions.navigateToPaymentSuccess(
        context,
        maintenanceAmount: maintenanceAmount,
        totalPaid: totalPaid,
        paymentMethod: paymentMethod,
        periodLabel: periodLabel,
        transactionId: transactionId,
        payAllPending: payAllPending,
        platformFee: platformFee,
        platformFeeGst: platformFeeGst,
      );

  /// Resume in-flight gateway payment after cold start / app resume.
  static Future<void> recoverPendingPayment({
    BuildContext? context,
    WidgetRef? ref,
    MaintenanceRepository? repository,
    bool navigate = true,
  }) =>
      GatewayPaymentRecovery.tryRecover(
        context: context,
        ref: ref,
        repository: repository,
        navigate: navigate,
      );

  /// Poll server for a saved pending payment (pending verification screen).
  static Future<GatewayPaymentPollResult?> pollPendingPayment({
    required MaintenanceRepository repository,
    required GatewayPendingPayment pending,
  }) async {
    if (pending.gateway == 'phonepe') {
      return repository.checkPhonePeStatus(pending.transactionId);
    }
    return repository.checkRazorpayStatus(pending.transactionId);
  }

  static BuildContext? get rootContext => appRootNavigatorKey.currentContext;
}
