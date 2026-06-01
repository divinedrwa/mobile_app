import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/upi_payment_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/providers/upi_payment_provider.dart';

/// Resident screen for paying maintenance via UPI.
///
/// Flow:
///   1. Shows payment details (what it's for, amount, payee).
///   2. "Pay via UPI App" or "Show QR Code" to make the payment.
///   3. After returning from UPI app → shows "Confirm Payment" step.
///   4. One-tap "I've paid" submit with optional UTR for faster verification.
class UpiPaymentScreen extends ConsumerStatefulWidget {
  const UpiPaymentScreen({
    super.key,
    this.amount,
    this.month,
    this.year,
    this.cycleId,
    this.remark,
    this.vpa,
    this.qrCodeUrl,
  });

  final double? amount;
  final int? month;
  final int? year;
  final String? cycleId;
  final String? remark;
  /// Pre-filled VPA from payment method selection (overrides upiConfig provider).
  final String? vpa;
  /// Pre-filled QR code URL from payment method selection.
  final String? qrCodeUrl;

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
  bool _returnedFromUpi = false;
  bool _showUtrField = false;

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
    if (state == AppLifecycleState.resumed && !_returnedFromUpi && !_submitted) {
      // User returned from UPI app — show confirmation step
      setState(() => _returnedFromUpi = true);
    }
  }

  String get _paymentRemark {
    if (widget.remark != null && widget.remark!.isNotEmpty) {
      return widget.remark!;
    }
    final month = widget.month ?? DateTime.now().month;
    final year = widget.year ?? DateTime.now().year;
    return 'Maintenance $month/$year';
  }

  String _buildUpiUri(String vpa, String payeeName, double amount) {
    return 'upi://pay?pa=${Uri.encodeComponent(vpa)}'
        '&pn=${Uri.encodeComponent(payeeName)}'
        '&am=${amount.toStringAsFixed(2)}'
        '&tn=${Uri.encodeComponent(_paymentRemark)}'
        '&cu=INR';
  }

  Future<void> _launchUpiApp(String upiUri) async {
    final uri = Uri.parse(upiUri);
    if (await canLaunchUrl(uri)) {
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
            remark: _paymentRemark,
          );
      ref.invalidate(myUpiPaymentsProvider);
      ref.invalidate(pendingMaintenanceProvider);
      ref.invalidate(residentBillingCycleProvider);
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
          // Use pre-filled params from payment method selection, or fall back to config
          final vpa = widget.vpa ?? config['upiVpa']?.toString() ?? '';
          final payeeName = config['payeeName']?.toString() ?? 'Society';
          final qrImageUrl = widget.qrCodeUrl ?? config['upiQrCodeUrl']?.toString();
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
    if (_submitted) return _buildSuccessState();

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final upiUri = amount > 0 ? _buildUpiUri(vpa, payeeName, amount) : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Payee info
        _buildPayeeCard(vpa, payeeName),
        const SizedBox(height: 16),

        // Payment remark
        _buildRemarkCard(),
        const SizedBox(height: 16),

        // Amount field
        Text('Amount',
            style: DesignTypography.label.copyWith(fontWeight: FontWeight.w600)),
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

        if (amount > 0) ...[
          // ── STEP 1: Pay via UPI App or QR ──
          if (!_returnedFromUpi) ...[
            // "Pay via UPI App" uses Android/iOS intent — hidden on web.
            if (!kIsWeb) ...[
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
            ],
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
              _buildQrSection(upiUri, qrImageUrl),
            ],
            const SizedBox(height: 20),
            // Direct submit option for QR/manual payers
            _buildConfirmSection(),
          ] else ...[
            // ── STEP 2: User returned from UPI app — confirm payment ──
            _buildPostUpiConfirmation(),
          ],
        ],

        // My submissions
        const SizedBox(height: 32),
        Text('My UPI Submissions',
            style:
                DesignTypography.label.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _MySubmissionsList(),
      ],
    );
  }

  Widget _buildPayeeCard(String vpa, String payeeName) {
    return Container(
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
    );
  }

  Widget _buildRemarkCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment for',
                  style: DesignTypography.captionSmall.copyWith(
                    color: const Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _paymentRemark,
                  style: DesignTypography.label.copyWith(
                    color: const Color(0xFF14532D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSection(String upiUri, String? qrImageUrl) {
    return Column(
      children: [
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
    );
  }

  /// Confirm section shown before/alongside UPI launch — for QR payers or
  /// those who paid externally and want to submit directly.
  Widget _buildConfirmSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Already paid? Confirm below',
            style: DesignTypography.label.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'After paying via UPI app or scanning QR, tap the button below to notify your admin.',
            style: DesignTypography.captionSmall
                .copyWith(color: DesignColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Optional UTR — collapsed by default
          _buildOptionalUtrField(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submitPayment,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: const Text("I've completed the payment"),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Post-UPI-app confirmation — shown after user returns from UPI app.
  Widget _buildPostUpiConfirmation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFFD97706), size: 48),
          const SizedBox(height: 12),
          Text(
            'Did your payment go through?',
            style: DesignTypography.headingM.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'If your UPI payment was successful, tap "Yes" to notify your admin for verification.',
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall
                .copyWith(color: const Color(0xFFB45309)),
          ),
          const SizedBox(height: 16),
          // Optional UTR
          _buildOptionalUtrField(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _returnedFromUpi = false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: const Text('No, retry'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submitPayment,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: const Text('Yes, I paid'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Collapsible UTR field — optional, helps admin verify faster.
  Widget _buildOptionalUtrField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showUtrField = !_showUtrField),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showUtrField
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: DesignColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add UTR / transaction ID (optional)',
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showUtrField) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _utrController,
            decoration: InputDecoration(
              hintText: 'e.g. 412345678901',
              helperText: 'Helps your admin verify faster',
              helperStyle: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignRadius.md),
              ),
              isDense: true,
            ),
          ),
        ],
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
              'Your admin will verify this payment.\nYou\'ll be notified once verified.',
              textAlign: TextAlign.center,
              style: DesignTypography.body
                  .copyWith(color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(DesignRadius.md),
              ),
              child: Text(
                _paymentRemark,
                style: DesignTypography.label.copyWith(
                  color: const Color(0xFF166534),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
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
                if (submission.remark != null && submission.remark!.isNotEmpty)
                  Text(submission.remark!,
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textPrimary)),
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
