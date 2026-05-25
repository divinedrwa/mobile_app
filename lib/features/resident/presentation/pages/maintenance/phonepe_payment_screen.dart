import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/repositories/maintenance_repository.dart';

final _maintenanceRepoProvider =
    Provider<MaintenanceRepository>((ref) => MaintenanceRepository());

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
  static const _maxPolls = 10;

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
    setState(() {
      _loading = true;
      _error = null;
      _showWebView = false;
      _paymentComplete = false;
    });

    try {
      final repo = ref.read(_maintenanceRepoProvider);
      final result = await repo.initiatePhonePePayment(
        cycleId: widget.cycleId.isNotEmpty ? widget.cycleId : null,
        payAllPending: widget.payAllPending,
      );

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
      _webViewController.loadRequest(Uri.parse(url));

      setState(() {
        _loading = false;
        _showWebView = true;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    // Detect redirect back from PhonePe (our redirect URL)
    if (request.url.contains('/phonepe/redirect')) {
      _onPaymentRedirect();
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onPaymentRedirect() {
    setState(() {
      _showWebView = false;
      _loading = true;
    });
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollStatus();
    });
    // Also poll immediately
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    if (_merchantTxnId == null || _polling) return;
    _polling = true;
    _pollCount++;

    try {
      final repo = ref.read(_maintenanceRepoProvider);
      final result = await repo.checkPhonePeStatus(_merchantTxnId!);
      final status = result['status'] as String? ?? 'UNKNOWN';

      if (status == 'SUCCESS') {
        _pollTimer?.cancel();
        ref.invalidate(pendingMaintenanceProvider);
        ref.invalidate(outstandingDuesProvider);
        ref.invalidate(maintenanceHistoryProvider);
        ref.invalidate(residentBillingCycleProvider);
        setState(() {
          _loading = false;
          _paymentComplete = true;
        });
        _showSuccessDialog();
        return;
      }

      if (status == 'FAILED') {
        _pollTimer?.cancel();
        setState(() {
          _loading = false;
          _error = 'Payment failed. Please try again.';
        });
        return;
      }
    } catch (_) {
      // Network error during poll — continue trying
    } finally {
      _polling = false;
    }

    if (_pollCount >= _maxPolls) {
      _pollTimer?.cancel();
      setState(() {
        _loading = false;
        _error = 'Payment is being processed. Please check back later.';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle,
            color: DesignColors.success, size: 48),
        title: const Text('Payment Successful'),
        content: Text(
          widget.payAllPending
              ? 'All outstanding bills (\u20B9${widget.amount.toStringAsFixed(0)}) have been recorded. Pull to refresh if any month still shows due.'
              : 'Your payment of \u20B9${widget.amount.toStringAsFixed(0)} has been processed successfully.',
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
