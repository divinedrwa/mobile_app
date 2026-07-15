import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/services/payment_orchestrator.dart';

/// Shown when the gateway reports payment but the server has not confirmed
/// within the in-app poll window (webhook / status API still pending).
class PaymentPendingVerificationScreen extends ConsumerStatefulWidget {
  const PaymentPendingVerificationScreen({
    super.key,
    required this.transactionId,
    required this.paymentMethod,
    required this.amount,
    required this.gateway,
    this.periodLabel,
    this.payAllPending = false,
    this.platformFee = 0,
    this.platformFeeGst = 0,
    this.totalPaid = 0,
  });

  final String transactionId;
  final String paymentMethod;
  final double amount;
  /// `phonepe` or `razorpay`
  final String gateway;
  final String? periodLabel;
  final bool payAllPending;
  final double platformFee;
  final double platformFeeGst;
  final double totalPaid;

  @override
  ConsumerState<PaymentPendingVerificationScreen> createState() =>
      _PaymentPendingVerificationScreenState();
}

class _PaymentPendingVerificationScreenState
    extends ConsumerState<PaymentPendingVerificationScreen> {
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _persistFromRoute();
      _checkAgain();
    });
  }

  Future<void> _persistFromRoute() async {
    if (widget.transactionId.isEmpty) return;
    await PaymentOrchestrator.persistPending(
      transactionId: widget.transactionId,
      gateway: widget.gateway,
      amount: widget.amount,
      periodLabel: widget.periodLabel,
      payAllPending: widget.payAllPending,
      platformFee: widget.platformFee,
      platformFeeGst: widget.platformFeeGst,
      totalPaid: widget.totalPaid,
      paymentMethod: widget.paymentMethod,
    );
  }

  Future<void> _checkAgain() async {
    if (_checking || widget.transactionId.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final poll = widget.gateway == 'razorpay'
          ? await repo.checkRazorpayStatus(widget.transactionId)
          : await repo.checkPhonePeStatus(widget.transactionId);

      if (!mounted) return;

      final handled = PaymentOrchestrator.handlePollResult(
        poll: poll,
        onSuccess: () {
          unawaited(PaymentOrchestrator.clearPending());
          invalidateMaintenancePaymentProviders(ref);
          PaymentOrchestrator.navigateToSuccess(
            context,
            maintenanceAmount: widget.amount,
            totalPaid: widget.totalPaid > 0 ? widget.totalPaid : widget.amount,
            paymentMethod: widget.paymentMethod,
            periodLabel: widget.periodLabel ?? '',
            transactionId: widget.transactionId,
            payAllPending: widget.payAllPending,
            platformFee: widget.platformFee,
            platformFeeGst: widget.platformFeeGst,
          );
        },
        onFailed: (message) {
          unawaited(PaymentOrchestrator.clearPending());
          setState(() => _error = message);
        },
        onGatewayUnavailable: (message) {
          setState(() => _error = message);
        },
      );

      if (!handled && mounted) {
        setState(() {
          _error =
              'Still confirming with ${widget.paymentMethod}. '
              'Please wait a minute and tap Check again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = userFacingMessage(e));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _backToDues() {
    invalidateMaintenancePaymentProviders(ref);
    context.go('/resident/maintenance/dues');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surface.defaultSurface,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Text(
          'Confirming payment',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.text.primary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.hourglass_top_rounded,
                size: 72,
                color: DesignColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                _error != null ? 'Payment status unclear' : 'Payment processing',
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error != null
                    ? 'We could not confirm whether your payment went through. '
                      'Tap "Check again" to verify. If your account was debited, '
                      'the payment will be recorded automatically.'
                    : 'Your payment is being processed. '
                      'We are waiting for the server to confirm it — this usually '
                      'takes under a minute, but can take longer on slow networks.',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignColors.borderLight),
                ),
                child: Column(
                  children: [
                    _infoRow('Amount', '₹${widget.amount.toStringAsFixed(0)}'),
                    if (widget.periodLabel != null && widget.periodLabel!.isNotEmpty)
                      _infoRow('Period', widget.periodLabel!),
                    _infoRow('Reference', widget.transactionId),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (_checking)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : _checkAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Check again'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _checking ? null : _backToDues,
                  child: const Text('Back to outstanding bills'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesignTypography.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
