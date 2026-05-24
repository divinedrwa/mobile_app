import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../data/repositories/maintenance_repository.dart';

final _maintenanceRepoProvider =
    Provider<MaintenanceRepository>((ref) => MaintenanceRepository());

class RazorpayPaymentScreen extends ConsumerStatefulWidget {
  const RazorpayPaymentScreen({
    super.key,
    required this.cycleId,
    required this.amount,
    required this.month,
    required this.year,
  });

  final String cycleId;
  final double amount;
  final int month;
  final int year;

  @override
  ConsumerState<RazorpayPaymentScreen> createState() =>
      _RazorpayPaymentScreenState();
}

class _RazorpayPaymentScreenState
    extends ConsumerState<RazorpayPaymentScreen> {
  late Razorpay _razorpay;
  bool _loading = true;
  String? _error;
  bool _paymentComplete = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _createOrder();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _createOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(_maintenanceRepoProvider);
      final result = await repo.createBillingOrder(cycleId: widget.cycleId);

      final orderId = result['orderId'] as String?;
      final key = result['key'] as String?;
      final amountPaise = result['amountPaise'];
      final currency = result['currency'] as String? ?? 'INR';

      if (orderId == null || key == null || amountPaise == null) {
        setState(() {
          _loading = false;
          _error = 'Invalid order response from server';
        });
        return;
      }

      final options = {
        'key': key,
        'amount': amountPaise,
        'currency': currency,
        'order_id': orderId,
        'name': 'Society Maintenance',
        'description':
            'Maintenance for ${_monthName(widget.month)} ${widget.year}',
        'timeout': 300, // 5 minutes
      };

      setState(() {
        _loading = false;
      });
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() {
      _paymentComplete = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle,
            color: DesignColors.success, size: 48),
        title: const Text('Payment Successful'),
        content: Text(
          'Your payment of \u20B9${widget.amount.toStringAsFixed(0)} has been processed successfully.\n\nPayment ID: ${response.paymentId ?? "N/A"}',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final message = response.message ?? 'Payment failed';
    setState(() {
      _error = message;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'External wallet selected: ${response.walletName ?? "Unknown"}')),
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (month >= 1 && month <= 12) ? names[month] : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Online Payment',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_paymentComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle,
              size: 64, color: DesignColors.success),
          const SizedBox(height: 16),
          Text('Payment completed',
              style: DesignTypography.headingM
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      );
    }

    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Creating payment order...',
            style: DesignTypography.label
                .copyWith(color: DesignColors.textSecondary),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: DesignColors.error),
          const SizedBox(height: 16),
          Text(
            'Payment Failed',
            style: DesignTypography.headingM
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall
                .copyWith(color: DesignColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createOrder,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    // Waiting for Razorpay to open
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.credit_card,
            size: 48, color: DesignColors.primary),
        const SizedBox(height: 16),
        Text(
          'Opening payment gateway...',
          style: DesignTypography.label
              .copyWith(color: DesignColors.textSecondary),
        ),
      ],
    );
  }
}
