import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/upi_payment_model.dart';
import '../../../data/providers/upi_payment_provider.dart';

/// Resident screen for paying maintenance via UPI.
///
/// Two paths:
///   1. "Pay via UPI App" — launches `upi://pay?...` intent.
///   2. "Show QR Code" — displays a scannable QR.
///
/// After returning from a UPI app the resident enters the UTR and submits.
class UpiPaymentScreen extends ConsumerStatefulWidget {
  const UpiPaymentScreen({
    super.key,
    this.amount,
    this.month,
    this.year,
    this.cycleId,
  });

  final double? amount;
  final int? month;
  final int? year;
  final String? cycleId;

  @override
  ConsumerState<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends ConsumerState<UpiPaymentScreen>
    with WidgetsBindingObserver {
  final _utrController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _showQr = false;
  bool _launchedUpi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.amount != null && widget.amount! > 0) {
      _amountController.text = widget.amount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _utrController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launchedUpi) {
      _launchedUpi = false;
      // Show UTR entry after returning from UPI app
      setState(() {});
    }
  }

  String _buildUpiUri(String vpa, String payeeName, double amount) {
    final month = widget.month ?? DateTime.now().month;
    final year = widget.year ?? DateTime.now().year;
    final note = 'Maintenance $month/$year';
    return 'upi://pay?pa=${Uri.encodeComponent(vpa)}'
        '&pn=${Uri.encodeComponent(payeeName)}'
        '&am=${amount.toStringAsFixed(2)}'
        '&tn=${Uri.encodeComponent(note)}'
        '&cu=INR';
  }

  Future<void> _launchUpiApp(String upiUri) async {
    final uri = Uri.parse(upiUri);
    if (await canLaunchUrl(uri)) {
      _launchedUpi = true;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI app found. Use QR code instead.')),
        );
        setState(() => _showQr = true);
      }
    }
  }

  Future<void> _submitPayment() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    final utr = _utrController.text.trim();
    if (utr.isNotEmpty && (utr.length < 6 || utr.length > 30)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UTR must be 6-30 characters')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(upiPaymentRepositoryProvider).submitUpiPayment(
            amount: amount,
            month: widget.month ?? DateTime.now().month,
            year: widget.year ?? DateTime.now().year,
            upiTransactionRef: utr.isNotEmpty ? utr : null,
            cycleId: widget.cycleId,
          );
      ref.invalidate(myUpiPaymentsProvider);
      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(upiConfigProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Pay via UPI',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: DesignColors.error),
              const SizedBox(height: 12),
              Text('Failed to load UPI config',
                  style: DesignTypography.label
                      .copyWith(color: DesignColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(upiConfigProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (config) {
          final vpa = config['upiVpa']?.toString() ?? '';
          final payeeName = config['payeeName']?.toString() ?? 'Society';
          final qrImageUrl = config['upiQrCodeUrl']?.toString();
          if (vpa.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'UPI payments are not configured for your society. '
                  'Please ask your admin to set up a UPI VPA.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildPaymentBody(vpa, payeeName, qrImageUrl: qrImageUrl);
        },
      ),
    );
  }

  Widget _buildPaymentBody(String vpa, String payeeName, {String? qrImageUrl}) {
    if (_submitted) {
      return _buildSuccessState();
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final upiUri =
        amount > 0 ? _buildUpiUri(vpa, payeeName, amount) : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Payee info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: DesignColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payeeName,
                        style: DesignTypography.label
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(vpa,
                        style: DesignTypography.captionSmall
                            .copyWith(color: DesignColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy VPA',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: vpa));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('VPA copied')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amount field
        Text('Amount', style: DesignTypography.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\u20B9 ',
            hintText: 'Enter amount',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // Action buttons
        if (amount > 0) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _launchUpiApp(upiUri),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Pay via UPI App'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showQr = !_showQr),
              icon: Icon(_showQr ? Icons.qr_code_2 : Icons.qr_code),
              label: Text(_showQr ? 'Hide QR Code' : 'Show QR Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
              ),
            ),
          ),
          if (_showQr) ...[
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: qrImageUrl != null && qrImageUrl.isNotEmpty
                    ? Image.network(
                        qrImageUrl,
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => QrImageView(
                          data: upiUri,
                          version: QrVersions.auto,
                          size: 220,
                        ),
                      )
                    : QrImageView(
                        data: upiUri,
                        version: QrVersions.auto,
                        size: 220,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Scan with any UPI app',
                style: DesignTypography.captionSmall
                    .copyWith(color: DesignColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // UTR entry
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: BorderRadius.circular(DesignRadius.lg),
              border: Border.all(color: DesignColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter Transaction Reference (UTR)',
                    style: DesignTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'After paying, enter the UTR from your UPI app (optional but helps verification)',
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _utrController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 412345678901',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submitPayment,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignRadius.md),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit for Verification'),
                  ),
                ),
              ],
            ),
          ),
        ],

        // My submissions
        const SizedBox(height: 32),
        Text('My UPI Submissions',
            style: DesignTypography.label
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _MySubmissionsList(),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 20),
            Text('Payment Submitted',
                style: DesignTypography.headingM
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Your admin will verify this payment. You\'ll be notified once verified.',
              textAlign: TextAlign.center,
              style: DesignTypography.body
                  .copyWith(color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MySubmissionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myUpiPaymentsProvider);
    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (submissions) {
        if (submissions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No submissions yet',
                style: DesignTypography.captionSmall
                    .copyWith(color: DesignColors.textSecondary)),
          );
        }
        return Column(
          children: submissions.map((s) => _SubmissionTile(s)).toList(),
        );
      },
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile(this.submission);
  final UpiPaymentModel submission;

  Color get _statusColor {
    switch (submission.status) {
      case 'VERIFIED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return DesignColors.error;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get _statusIcon {
    switch (submission.status) {
      case 'VERIFIED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(color: DesignColors.border),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: _statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u20B9${submission.amount.toStringAsFixed(0)} - ${submission.month}/${submission.year}',
                  style: DesignTypography.label
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (submission.upiTransactionRef != null &&
                    submission.upiTransactionRef!.isNotEmpty)
                  Text('UTR: ${submission.upiTransactionRef}',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary)),
                if (submission.isRejected &&
                    submission.rejectionReason != null)
                  Text('Reason: ${submission.rejectionReason}',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.error)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              submission.status,
              style: DesignTypography.captionSmall.copyWith(
                color: _statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
