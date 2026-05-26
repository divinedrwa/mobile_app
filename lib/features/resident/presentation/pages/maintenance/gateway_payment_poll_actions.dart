import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/utils/gateway_payment_status.dart';

/// Shared handling for PhonePe / Razorpay status poll results.
class GatewayPaymentPollActions {
  GatewayPaymentPollActions._();

  /// Returns true when the poll result was terminal (success, failed, or unavailable).
  static bool handlePollResult({
    required GatewayPaymentPollResult poll,
    required VoidCallback onSuccess,
    required void Function(String message) onFailed,
    required void Function(String message) onGatewayUnavailable,
  }) {
    if (poll.isRecordedOrCompleted) {
      onSuccess();
      return true;
    }
    if (poll.isFailed) {
      onFailed(poll.failureMessage);
      return true;
    }
    if (poll.isGatewayUnavailable) {
      onGatewayUnavailable(
        poll.detail?.isNotEmpty == true
            ? poll.detail!
            : 'Could not verify payment with the gateway. Try again later.',
      );
      return true;
    }
    return false;
  }

  static void navigateToPaymentSuccess(
    BuildContext context, {
    required double maintenanceAmount,
    required double totalPaid,
    required String paymentMethod,
    required String periodLabel,
    required String transactionId,
    bool payAllPending = false,
    double platformFee = 0,
    double platformFeeGst = 0,
  }) {
    context.go(
      Uri(
        path: '/resident/maintenance/payment-success',
        queryParameters: {
          'amount': maintenanceAmount.toStringAsFixed(2),
          if (platformFee > 0) 'platformFee': platformFee.toStringAsFixed(2),
          if (platformFeeGst > 0) 'platformFeeGst': platformFeeGst.toStringAsFixed(2),
          'totalPaid': totalPaid.toStringAsFixed(2),
          'txnId': transactionId,
          'method': paymentMethod,
          'period': periodLabel,
          if (payAllPending) 'payAll': 'true',
        },
      ).toString(),
    );
  }
}
