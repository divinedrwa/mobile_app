import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_navigator_keys.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/repositories/maintenance_repository.dart';
import 'gateway_payment_poll_actions.dart';
import 'gateway_pending_payment_store.dart';

/// Reconciles a persisted in-flight gateway payment after app resume / cold start.
///
/// Server-side, Razorpay webhooks and `GET …/razorpay/status/:orderId` also settle
/// payments when the app is closed — this bridges the gap until the resident opens
/// the app again.
class GatewayPaymentRecovery {
  GatewayPaymentRecovery._();

  static bool _recovering = false;

  static bool _isOnPaymentFlow(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path.contains('/payment-pending') ||
        path.contains('/razorpay-pay') ||
        path.contains('/phonepe-pay') ||
        path.contains('/payment-success');
  }

  /// Poll server for a saved pending payment; navigate or refresh UI when resolved.
  static Future<void> tryRecover({
    BuildContext? context,
    WidgetRef? ref,
    MaintenanceRepository? repository,
    bool navigate = true,
  }) async {
    if (_recovering) return;
    final ctx = context ?? appRootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final pending = GatewayPendingPaymentStore.read();
    if (pending == null) return;

    final currentUserId = GatewayPendingPaymentStore.currentUserId();
    if (currentUserId != null &&
        pending.userId.isNotEmpty &&
        pending.userId != currentUserId) {
      await GatewayPendingPaymentStore.clear();
      return;
    }

    if (pending.isExpired) {
      await GatewayPendingPaymentStore.clear();
      return;
    }

    _recovering = true;
    try {
      final MaintenanceRepository repo = repository ??
          (ref != null
              ? ref.read(maintenanceRepositoryProvider)
              : ProviderScope.containerOf(ctx)
                  .read(maintenanceRepositoryProvider));

      final poll = pending.gateway == 'phonepe'
          ? await repo.checkPhonePeStatus(pending.transactionId)
          : await repo.checkRazorpayStatus(pending.transactionId);

      if (!ctx.mounted) return;

      if (poll.isRecordedOrCompleted) {
        await GatewayPendingPaymentStore.clear();
        if (ref != null) invalidateMaintenancePaymentProviders(ref);
        if (navigate && ctx.mounted) {
          GatewayPaymentPollActions.navigateToPaymentSuccess(
            ctx,
            maintenanceAmount: pending.amount,
            totalPaid:
                pending.totalPaid > 0 ? pending.totalPaid : pending.amount,
            paymentMethod: pending.paymentMethod,
            periodLabel: pending.periodLabel ?? '',
            transactionId: pending.transactionId,
            payAllPending: pending.payAllPending,
            platformFee: pending.platformFee,
            platformFeeGst: pending.platformFeeGst,
          );
        }
        return;
      }

      if (poll.isFailed) {
        await GatewayPendingPaymentStore.clear();
        if (ref != null) invalidateMaintenancePaymentProviders(ref);
        return;
      }

      // Still processing — surface the pending screen unless user is already in checkout.
      if (navigate && ctx.mounted && !_isOnPaymentFlow(ctx)) {
        GatewayPaymentPollActions.navigateToPaymentPending(
          ctx,
          transactionId: pending.transactionId,
          paymentMethod: pending.paymentMethod,
          gateway: pending.gateway,
          amount: pending.amount,
          periodLabel: pending.periodLabel,
          payAllPending: pending.payAllPending,
          platformFee: pending.platformFee,
          platformFeeGst: pending.platformFeeGst,
          totalPaid: pending.totalPaid,
        );
      }
    } catch (_) {
      // Transient network — keep pending for next resume.
    } finally {
      _recovering = false;
    }
  }
}
