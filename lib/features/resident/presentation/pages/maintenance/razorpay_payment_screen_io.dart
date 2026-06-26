import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../data/providers/maintenance_provider.dart';
import 'gateway_payment_poll_actions.dart';
import 'gateway_sdk_errors.dart';

class RazorpayPaymentScreen extends ConsumerStatefulWidget {
  const RazorpayPaymentScreen({
    super.key,
    required this.cycleId,
    required this.amount,
    required this.month,
    required this.year,
    this.payAllPending = false,
  });

  final String cycleId;
  final double amount;
  final int month;
  final int year;
  final bool payAllPending;

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
  bool _checkoutActive = false;
  /// Set once Razorpay SDK returns (success or error). Once the SDK has
  /// dismissed, always allow back — the user shouldn't be trapped.
  bool _sdkReturned = false;
  String? _razorpayOrderId;
  Timer? _verifyTimer;
  int _verifyPollCount = 0;
  bool _verifying = false;
  /// Incremented on each _createOrder call. Stale poll responses are ignored.
  int _verifyGeneration = 0;
  static const _maxVerifyPolls = 40;
  /// After ambiguous SDK error, poll briefly then show the SDK message.
  static const _maxErrorVerifyPolls = 2;
  static const _verifyPollInterval = Duration(seconds: 2);
  String? _sdkErrorMessage;
  String _loadingMessage = 'Preparing checkout...';
  double _maintenanceDue = 0;
  double _platformFee = 0;
  double _platformFeeGst = 0;
  double _totalPayable = 0;
  String _idempotencyKey = const Uuid().v4();

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
    _verifyTimer?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _createOrder() async {
    _idempotencyKey = const Uuid().v4();
    _verifyTimer?.cancel();
    _verifyGeneration++;
    _sdkReturned = false;
    _sdkErrorMessage = null;
    setState(() {
      _loading = true;
      _error = null;
      _checkoutActive = false;
      _loadingMessage = 'Preparing checkout...';
    });
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final result = await repo.createBillingOrder(
        cycleId: widget.cycleId.isNotEmpty ? widget.cycleId : null,
        payAllPending: widget.payAllPending,
        idempotencyKey: _idempotencyKey,
      );

      final orderId = result['orderId'] as String?;
      final key = result['key'] as String?;
      final amountPaise = result['amountPaise'];
      final currency = result['currency'] as String? ?? 'INR';
      final autoSettledFromCredit = result['autoSettledFromCredit'] == true;
      final autoSettled = result['autoSettled'] == true;

      if (autoSettledFromCredit || autoSettled || (orderId == null && _readAmount(amountPaise) == 0)) {
        unawaited(GatewayPaymentPollActions.clearPersistedGatewayPayment());
        _maintenanceDue = _readAmount(result['totalDue']) ?? widget.amount;
        invalidateMaintenancePaymentProviders(ref);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _paymentComplete = true;
        });
        GatewayPaymentPollActions.navigateToPaymentSuccess(
          context,
          maintenanceAmount: _maintenanceDue,
          totalPaid: _maintenanceDue,
          paymentMethod: 'Razorpay',
          periodLabel: widget.payAllPending
              ? 'All outstanding'
              : '${_monthName(widget.month)} ${widget.year}',
          transactionId: result['paymentId']?.toString() ?? '',
          payAllPending: widget.payAllPending,
        );
        return;
      }

      if (orderId == null || key == null || amountPaise == null) {
        setState(() {
          _loading = false;
          _error = 'Invalid order response from server';
        });
        return;
      }

      final maintenance = _readAmount(result['maintenanceAmount']) ??
          _readAmount(result['totalDue']) ??
          widget.amount;
      final platformFee = _readAmount(result['platformFee']) ?? 0;
      final platformFeeGst = _readAmount(result['platformFeeGst']) ?? 0;
      final totalPayable =
          _readAmount(result['totalPayable']) ?? (maintenance + platformFee + platformFeeGst);

      _maintenanceDue = maintenance;
      _platformFee = platformFee;
      _platformFeeGst = platformFeeGst;
      _totalPayable = totalPayable;

      // Show the society's name as the checkout title, with the maintenance
      // period as the description (selected month, or all outstanding).
      final societyName = ref.read(authProvider).user?.societyName?.trim();
      final checkoutTitle = (societyName != null && societyName.isNotEmpty)
          ? societyName
          : 'Society Maintenance';
      final checkoutDescription = widget.payAllPending
          ? 'Society maintenance · All outstanding dues'
          : 'Society maintenance · ${_monthName(widget.month)} ${widget.year}';

      final options = {
        'key': key,
        'amount': amountPaise,
        'currency': currency,
        'order_id': orderId,
        'name': checkoutTitle,
        'description': checkoutDescription,
        'timeout': 300, // 5 minutes
        'method': {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
        },
      };

      if (!mounted) return;
      if (platformFee > 0 || platformFeeGst > 0) {
        final proceed = await _confirmGatewayFees();
        if (!proceed) {
          if (mounted) {
            // User cancelled fee confirmation — go back to previous screen
            context.pop();
          }
          return;
        }
      }

      if (!mounted) return;
      _razorpayOrderId = orderId;
      setState(() {
        _loading = false;
        _loadingMessage = 'Opening secure checkout...';
      });
      final period = widget.payAllPending
          ? 'All outstanding'
          : '${_monthName(widget.month)} ${widget.year}';
      unawaited(
        GatewayPaymentPollActions.persistPendingGatewayPayment(
          transactionId: orderId,
          gateway: 'razorpay',
          amount: _maintenanceDue,
          periodLabel: period,
          payAllPending: widget.payAllPending,
          platformFee: _platformFee,
          platformFeeGst: _platformFeeGst,
          totalPaid: _totalPayable,
          paymentMethod: 'Razorpay',
        ),
      );
      _checkoutActive = true;
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    _sdkReturned = true;
    _checkoutActive = false;
    _sdkErrorMessage = null;
    setState(() {
      _loading = true;
      _error = null;
      _loadingMessage = 'Confirming payment...';
    });
    _startServerVerifyPolling(
      razorpayPaymentId: response.paymentId,
      maxPolls: _maxVerifyPolls,
    );
  }

  void _startServerVerifyPolling({
    required String? razorpayPaymentId,
    required int maxPolls,
  }) {
    _verifyTimer?.cancel();
    _verifyPollCount = 0;
    unawaited(_runServerVerifyPolls(
      razorpayPaymentId: razorpayPaymentId,
      maxPolls: maxPolls,
    ));
  }

  Future<void> _runServerVerifyPolls({
    required String? razorpayPaymentId,
    required int maxPolls,
  }) async {
    final gen = _verifyGeneration;
    while (mounted && gen == _verifyGeneration && _verifyPollCount < maxPolls) {
      final handled = await _verifyServerPayment(razorpayPaymentId);
      if (handled || !mounted || gen != _verifyGeneration) return;
      if (_verifyPollCount >= maxPolls) break;
      await Future.delayed(_verifyPollInterval);
    }
    if (!mounted || gen != _verifyGeneration) return;
    if (_sdkErrorMessage != null) {
      invalidateMaintenancePaymentProviders(ref);
      setState(() {
        _loading = false;
        _error = _sdkErrorMessage;
      });
      return;
    }
    final orderId = _razorpayOrderId;
    if (orderId == null || orderId.isEmpty) return;
    final period = widget.payAllPending
        ? 'All outstanding'
        : '${_monthName(widget.month)} ${widget.year}';
    GatewayPaymentPollActions.navigateToPaymentPending(
      context,
      transactionId: orderId,
      paymentMethod: 'Razorpay',
      gateway: 'razorpay',
      amount: _maintenanceDue,
      periodLabel: period,
      payAllPending: widget.payAllPending,
      platformFee: _platformFee,
      platformFeeGst: _platformFeeGst,
      totalPaid: _totalPayable,
    );
  }

  /// Returns true when the poll result was terminal (success / failed / unavailable).
  Future<bool> _verifyServerPayment(String? razorpayPaymentId) async {
    final orderId = _razorpayOrderId;
    if (orderId == null || orderId.isEmpty || !mounted || _verifying) return false;

    _verifying = true;
    _verifyPollCount++;
    final gen = _verifyGeneration;
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final poll = await repo.checkRazorpayStatus(orderId);

      if (!mounted || gen != _verifyGeneration) return false;

      final period = widget.payAllPending
          ? 'All outstanding'
          : '${_monthName(widget.month)} ${widget.year}';

      var handled = false;
      handled = GatewayPaymentPollActions.handlePollResult(
        poll: poll,
        onSuccess: () {
          _verifyTimer?.cancel();
          unawaited(GatewayPaymentPollActions.clearPersistedGatewayPayment());
          invalidateMaintenancePaymentProviders(ref);
          setState(() {
            _loading = false;
            _paymentComplete = true;
            _error = null;
          });
          GatewayPaymentPollActions.navigateToPaymentSuccess(
            context,
            maintenanceAmount: _maintenanceDue,
            totalPaid: _totalPayable,
            paymentMethod: 'Razorpay',
            periodLabel: period,
            transactionId: razorpayPaymentId ?? orderId,
            payAllPending: widget.payAllPending,
            platformFee: _platformFee,
            platformFeeGst: _platformFeeGst,
          );
        },
        onFailed: (message) {
          _verifyTimer?.cancel();
          if (poll.isFailed) {
            unawaited(GatewayPaymentPollActions.clearPersistedGatewayPayment());
          }
          invalidateMaintenancePaymentProviders(ref);
          setState(() {
            _loading = false;
            _error = message;
          });
        },
        onGatewayUnavailable: (message) {
          _verifyTimer?.cancel();
          invalidateMaintenancePaymentProviders(ref);
          setState(() {
            _loading = false;
            _error = message;
          });
        },
      );
      return handled;
    } catch (_) {
      return false;
    } finally {
      _verifying = false;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _sdkReturned = true;
    _checkoutActive = false;
    _verifyTimer?.cancel();
    final formatted = GatewaySdkErrors.formatRazorpayFailureMessage(response.message);
    _sdkErrorMessage = formatted;

    if (GatewaySdkErrors.shouldSkipServerVerifyAfterRazorpayFailure(
      message: response.message,
      code: response.code,
    )) {
      // User cancelled / timed out before submitting — the order was never paid.
      // Clear the persisted-pending record so resume-recovery doesn't later show a
      // false "payment processing" screen for an abandoned checkout.
      unawaited(GatewayPaymentPollActions.clearPersistedGatewayPayment());
      invalidateMaintenancePaymentProviders(ref);
      setState(() {
        _loading = false;
        _error = formatted;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _loadingMessage = 'Checking payment status...';
    });
    _startServerVerifyPolling(
      razorpayPaymentId: null,
      maxPolls: _maxErrorVerifyPolls,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _sdkReturned = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'External wallet selected: ${response.walletName ?? "Unknown"}')),
    );
  }

  double? _readAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<bool> _confirmGatewayFees() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Payment summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _feeRow('Maintenance due', _maintenanceDue),
            if (_platformFee > 0) _feeRow('Razorpay platform fee', _platformFee),
            if (_platformFeeGst > 0) _feeRow('GST on platform fee', _platformFeeGst),
            const Divider(),
            _feeRow('Total payable now', _totalPayable, bold: true),
            const SizedBox(height: 8),
            Text(
              'Platform fee and GST are added on top of your maintenance due.',
              style: DesignTypography.bodySmall
                  .copyWith(color: DesignColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue to pay'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _feeRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: DesignTypography.label.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: DesignColors.textPrimary,
            ),
          ),
          Text(
            '\u20B9${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}',
            style: DesignTypography.label.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: DesignColors.textPrimary,
            ),
          ),
        ],
      ),
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
    return PopScope(
      canPop: !_checkoutActive || _paymentComplete || _error != null || _sdkReturned,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete or cancel the payment first'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.surface.background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          backgroundColor: context.surface.defaultSurface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
            onPressed: () {
              if (!_checkoutActive || _paymentComplete || _error != null || _sdkReturned) {
                context.pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please complete or cancel the payment first'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          title: Text(
            'Online Payment',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.text.primary),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_paymentComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle,
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
            _loadingMessage,
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
          Icon(Icons.error_outline,
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
        Icon(Icons.credit_card,
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
