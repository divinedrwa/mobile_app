import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/providers/maintenance_provider.dart';
import 'gateway_payment_poll_actions.dart';

class PhonePePaymentScreen extends ConsumerStatefulWidget {
  const PhonePePaymentScreen({
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
  ConsumerState<PhonePePaymentScreen> createState() =>
      _PhonePePaymentScreenState();
}

class _PhonePePaymentScreenState extends ConsumerState<PhonePePaymentScreen> {
  bool _loading = true;
  String? _error;
  bool _paymentComplete = false;
  bool _showWebView = false;
  String? _merchantTxnId;
  Timer? _pollTimer;
  int _pollCount = 0;
  bool _polling = false;
  static const _maxPolls = 20;
  String _idempotencyKey = const Uuid().v4();
  double _serverAmount = 0;

  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigation,
      ));
    _initiatePayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    _idempotencyKey = const Uuid().v4();
    setState(() {
      _loading = true;
      _error = null;
      _showWebView = false;
      _paymentComplete = false;
    });

    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final result = await repo.initiatePhonePePayment(
        cycleId: widget.cycleId.isNotEmpty ? widget.cycleId : null,
        payAllPending: widget.payAllPending,
        idempotencyKey: _idempotencyKey,
      );

      if (!mounted) return;

      final url = result['redirectUrl'] as String?;
      final txnId = result['merchantTransactionId'] as String?;

      if (url == null || txnId == null) {
        setState(() {
          _loading = false;
          _error = 'Invalid response from server';
        });
        return;
      }

      _merchantTxnId = txnId;
      _serverAmount = _readAmount(result['totalDue']) ?? widget.amount;
      unawaited(_webViewController.loadRequest(Uri.parse(url)));

      setState(() {
        _loading = false;
        _showWebView = true;
      });

      // Poll while the checkout WebView is open — sandbox often never hits our
      // redirect URL, so waiting for redirect-only polling leaves PENDING forever.
      _pollCount = 0;
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _pollStatus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = request.url;
    // Detect redirect back from PhonePe (our redirect URL on API_BASE_URL host)
    if (url.contains('/phonepe/redirect')) {
      _onPaymentRedirect();
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onPaymentRedirect() {
    if (!mounted) return;
    setState(() {
      _showWebView = false;
      _loading = true;
    });
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    if (_merchantTxnId == null || _polling) return;
    _polling = true;
    _pollCount++;

    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      final poll = await repo.checkPhonePeStatus(_merchantTxnId!);

      if (!mounted) return;

      final handled = GatewayPaymentPollActions.handlePollResult(
        poll: poll,
        onSuccess: () {
          _pollTimer?.cancel();
          invalidateMaintenancePaymentProviders(ref);
          setState(() {
            _loading = false;
            _paymentComplete = true;
          });
          _showSuccessScreen();
        },
        onFailed: (message) {
          _pollTimer?.cancel();
          setState(() {
            _loading = false;
            _error = message;
          });
        },
        onGatewayUnavailable: (message) {
          _pollTimer?.cancel();
          setState(() {
            _loading = false;
            _error = message;
          });
        },
      );
      if (handled) return;
    } catch (_) {
      // Network error during poll — continue trying
    } finally {
      _polling = false;
    }

    if (!mounted) return;
    if (_pollCount >= _maxPolls) {
      _pollTimer?.cancel();
      // Payment was not explicitly confirmed or rejected — likely still
      // processing. Pop back so the parent refreshes data; a toast tells
      // the user the amount will reflect shortly.
      invalidateMaintenancePaymentProviders(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment is being verified. It will reflect shortly.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        context.pop(true);
      }
    }
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? names[month] : '';
  }

  void _showSuccessScreen() {
    if (!mounted) return;
    final amount = _serverAmount > 0 ? _serverAmount : widget.amount;
    final period = widget.payAllPending
        ? 'All outstanding'
        : '${_monthName(widget.month)} ${widget.year}';

    GatewayPaymentPollActions.navigateToPaymentSuccess(
      context,
      maintenanceAmount: amount,
      totalPaid: amount,
      paymentMethod: 'PhonePe',
      periodLabel: period,
      transactionId: _merchantTxnId ?? '',
      payAllPending: widget.payAllPending,
    );
  }

  double? _readAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool get _canPop =>
      !_showWebView && !_loading || _paymentComplete || _error != null;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
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
        backgroundColor: DesignColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: DesignColors.background,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
            onPressed: () {
              if (_canPop) {
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
            'PhonePe Payment',
            style: DesignTypography.headingM.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _showWebView
            ? WebViewWidget(controller: _webViewController)
            : Center(
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
            _merchantTxnId != null
                ? 'Verifying payment...'
                : 'Initiating PhonePe payment...',
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
            onPressed: _initiatePayment,
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

    return const SizedBox.shrink();
  }
}
