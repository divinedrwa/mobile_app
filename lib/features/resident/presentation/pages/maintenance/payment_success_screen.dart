import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/providers/maintenance_provider.dart';

/// Full-screen payment success confirmation shown after Razorpay / PhonePe /
/// UPI payment completes. Displays transaction details, amount breakdown, and
/// a prominent success indicator with haptic feedback.
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    this.platformFee = 0,
    this.platformFeeGst = 0,
    this.totalPaid = 0,
    this.transactionId,
    this.paymentMethod = 'Online',
    this.billingPeriod,
    this.payAllPending = false,
  });

  final double amount;
  final double platformFee;
  final double platformFeeGst;
  final double totalPaid;
  final String? transactionId;
  final String paymentMethod;
  final String? billingPeriod;
  final bool payAllPending;

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    DesignHaptics.success();
    invalidateMaintenancePaymentProviders(ref);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    invalidateMaintenancePaymentProviders(ref);
    context.go('/resident/maintenance/dues');
  }

  String _fmt(double n) {
    final formatted = n.truncateToDouble() == n
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(2);
    return '\u20B9$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTotal =
        widget.totalPaid > 0 ? widget.totalPaid : widget.amount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: DesignColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.screenPaddingH,
              vertical: DesignSpacing.xl,
            ),
            child: Column(
              children: [
                const Spacer(flex: 1),

                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DesignColors.primary.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 72,
                      color: DesignColors.success,
                    ),
                  ),
                ),

                const SizedBox(height: DesignSpacing.xl),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    'Payment Successful',
                    style: DesignTypography.headingL.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: DesignSpacing.sm),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    widget.payAllPending
                        ? 'All outstanding dues have been paid.'
                        : 'Your maintenance payment was recorded.',
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: DesignSpacing.xxl),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(DesignSpacing.lg),
                    decoration: DesignComponents.cardDecoration(),
                    child: Column(
                      children: [
                        _row('Maintenance Due', _fmt(widget.amount)),
                        if (widget.platformFee > 0)
                          _row('Platform Fee', _fmt(widget.platformFee)),
                        if (widget.platformFeeGst > 0)
                          _row('GST on Fee', _fmt(widget.platformFeeGst)),
                        if (widget.platformFee > 0 ||
                            widget.platformFeeGst > 0) ...[
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: DesignSpacing.sm),
                            child: Divider(color: DesignColors.divider),
                          ),
                          _row('Total Paid', _fmt(effectiveTotal), bold: true),
                        ],
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: DesignSpacing.sm),
                          child: Divider(color: DesignColors.divider),
                        ),
                        _row('Payment Method', widget.paymentMethod),
                        if (widget.billingPeriod != null)
                          _row('Billing Period', widget.billingPeriod!),
                        if (widget.transactionId != null &&
                            widget.transactionId!.isNotEmpty)
                          _row('Transaction ID', widget.transactionId!),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _done,
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignSpacing.buttonPaddingV + 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignRadius.borderMD,
                      ),
                    ),
                    child: const Text('View outstanding bills', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: DesignSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: DesignTypography.label.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
