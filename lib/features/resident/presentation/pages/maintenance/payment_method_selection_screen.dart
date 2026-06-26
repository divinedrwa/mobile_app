import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/screen_skeletons.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/payment_method_model.dart';
import '../../../data/providers/payment_methods_provider.dart';

/// Payment types that require native mobile capabilities (UPI intents,
/// WebView-based PhonePe SDK). Hidden on web where only Razorpay (Checkout.js)
/// and bank transfer (display-only) work.
const _mobileOnlyPaymentTypes = {'UPI_VPA', 'UPI_QR', 'PHONEPE'};

/// Residents should prefer direct UPI (no gateway fee); Razorpay second.
int _paymentMethodSortKey(PaymentMethodModel m) {
  switch (m.type) {
    case 'UPI_VPA':
      return 0;
    case 'UPI_QR':
      return 1;
    case 'RAZORPAY':
      return 2;
    case 'PHONEPE':
      return 3;
    case 'BANK_TRANSFER':
      return 4;
    default:
      return 5;
  }
}

List<PaymentMethodModel> _sortPaymentMethods(List<PaymentMethodModel> methods) {
  final sorted = List<PaymentMethodModel>.from(methods);
  sorted.sort((a, b) {
    final byType = _paymentMethodSortKey(a).compareTo(_paymentMethodSortKey(b));
    if (byType != 0) return byType;
    return a.sortOrder.compareTo(b.sortOrder);
  });
  return sorted;
}

/// Screen that shows enabled payment methods and lets the resident pick one.
///
/// After selecting a method, navigates to the appropriate payment flow:
/// - UPI_VPA / UPI_QR → UPI payment screen (with pre-filled VPA / QR)
/// - BANK_TRANSFER → shows bank details (copy-able)
/// - RAZORPAY → existing Razorpay flow (future)
/// - PHONEPE → placeholder
class PaymentMethodSelectionScreen extends ConsumerWidget {
  const PaymentMethodSelectionScreen({
    super.key,
    required this.amount,
    required this.month,
    required this.year,
    this.cycleId,
    this.remark,
    this.payAllPending = false,
  });

  final double amount;
  final int month;
  final int year;
  final String? cycleId;
  final String? remark;
  final bool payAllPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentMethodsListProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surface.defaultSurface,
        leading: IconButton(
          tooltip: 'Go back',
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose payment method',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.text.primary),
            ),
            Text(
              'Select how you want to pay',
              style: TextStyle(fontSize: 12, color: context.text.secondary, height: 1.2),
            ),
          ],
        ),
      ),
      body: async.when(
        loading: () => const DetailSkeleton(heroHeight: 120),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: EnterpriseInfoBanner(
            icon: Icons.error_outline_rounded,
            tone: EnterpriseTone.danger,
            title: 'Failed to load payment methods',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(paymentMethodsListProvider),
          ),
        ),
        data: (methods) {
          final filtered = kIsWeb
              ? methods.where((m) => !_mobileOnlyPaymentTypes.contains(m.type)).toList()
              : methods;
          if (filtered.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No payment methods configured for your society. '
                  'Please ask your admin to set up payment options.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildMethodList(context, _sortPaymentMethods(filtered));
        },
      ),
    );
  }

  Widget _buildMethodList(BuildContext context, List<PaymentMethodModel> methods) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Amount header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(Icons.currency_rupee, size: 20, color: DesignColors.primary),
              const SizedBox(width: 8),
              Text(
                'Amount to pay: ',
                style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
              ),
              Text(
                '\u20B9${amount.toStringAsFixed(0)}',
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Select a payment method',
          style: DesignTypography.label.copyWith(
            color: DesignColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        ...methods.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MethodTile(
                method: m,
                onTap: () => _onMethodSelected(context, m),
              ),
            )),
      ],
    );
  }

  void _onMethodSelected(BuildContext context, PaymentMethodModel method) {
    switch (method.type) {
      case 'UPI_VPA':
      case 'UPI_QR':
        // Navigate to UPI payment screen with VPA/QR from the selected method
        final params = <String, String>{
          'amount': amount.toStringAsFixed(0),
          'month': '$month',
          'year': '$year',
        };
        if (cycleId != null && cycleId!.isNotEmpty) params['cycleId'] = cycleId!;
        if (remark != null && remark!.isNotEmpty) params['remark'] = remark!;
        // Pass VPA and QR URL as query params so UPI screen uses them
        if (method.vpa != null) params['vpa'] = method.vpa!;
        if (method.qrCodeUrl != null) params['qrCodeUrl'] = method.qrCodeUrl!;
        final query = '?${Uri(queryParameters: params).query}';
        context.push('/resident/maintenance/upi-pay$query');

      case 'BANK_TRANSFER':
        _showBankDetails(context, method);

      case 'RAZORPAY':
        if (!payAllPending && (cycleId == null || cycleId!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Online payment requires a billing cycle')),
          );
          return;
        }
        final rpParams = <String, String>{
          'amount': amount.toStringAsFixed(0),
          'month': '$month',
          'year': '$year',
          if (payAllPending) 'payAll': 'true',
          if (cycleId != null && cycleId!.isNotEmpty) 'cycleId': cycleId!,
        };
        final rpQuery = '?${Uri(queryParameters: rpParams).query}';
        context.push<bool>('/resident/maintenance/razorpay-pay$rpQuery').then((paid) {
          if (paid == true && context.mounted) context.pop(true);
        });

      case 'PHONEPE':
        if (!payAllPending && (cycleId == null || cycleId!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Online payment requires a billing cycle')),
          );
          return;
        }
        final ppParams = <String, String>{
          'amount': amount.toStringAsFixed(0),
          'month': '$month',
          'year': '$year',
          if (payAllPending) 'payAll': 'true',
          if (cycleId != null && cycleId!.isNotEmpty) 'cycleId': cycleId!,
        };
        final ppQuery = '?${Uri(queryParameters: ppParams).query}';
        context.push<bool>('/resident/maintenance/phonepe-pay$ppQuery').then((paid) {
          if (paid == true && context.mounted) context.pop(true);
        });
    }
  }

  void _showBankDetails(BuildContext context, PaymentMethodModel method) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BankDetailsSheet(method: method),
    );
  }
}

// ── Method Tile ──────────────────────────────────────────────────────

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, required this.onTap});

  final PaymentMethodModel method;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method.type) {
      case 'BANK_TRANSFER':
        return Icons.account_balance;
      case 'UPI_VPA':
        return Icons.phone_android;
      case 'UPI_QR':
        return Icons.qr_code_2;
      case 'RAZORPAY':
        return Icons.credit_card;
      case 'PHONEPE':
        return Icons.smartphone;
      default:
        return Icons.payment;
    }
  }

  bool get _isUpi => method.type == 'UPI_VPA' || method.type == 'UPI_QR';

  String? get _detailLine {
    switch (method.type) {
      case 'UPI_VPA':
        return method.vpa;
      case 'UPI_QR':
        return 'Scan QR code in any UPI app';
      case 'RAZORPAY':
        return 'Card · Net banking · Wallets';
      case 'BANK_TRANSFER':
        return 'Transfer to bank account';
      case 'PHONEPE':
        return 'Pay via PhonePe app';
      default:
        return null;
    }
  }

  String get _helperText {
    if (_isUpi) {
      return 'Pay in your UPI app, then tap I\'ve paid on the next screen. '
          'Admin will verify once payment is received — maintenance shows as paid after confirmation.';
    }
    if (method.type == 'RAZORPAY') {
      return 'Instant online payment. A platform fee and GST are added at checkout on top of your maintenance amount.';
    }
    if (method.type == 'PHONEPE') {
      return 'Instant online payment. Platform fee and GST may apply at checkout.';
    }
    if (method.type == 'BANK_TRANSFER') {
      return 'Transfer the amount and share the receipt with your admin for verification.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isRecommended = _isUpi;
    final detail = _detailLine;
    final helper = _helperText;

    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(
              color: isRecommended
                  ? DesignColors.primary.withValues(alpha: 0.35)
                  : DesignColors.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DesignColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
                child: Icon(_icon, size: 22, color: DesignColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _isUpi ? 'UPI' : method.displayName,
                          style: DesignTypography.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DesignColors.textPrimary,
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(DesignRadius.sm),
                            ),
                            child: Text(
                              'Recommended',
                              style: DesignTypography.captionSmall.copyWith(
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (detail != null && detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: DesignTypography.bodySmall.copyWith(
                          color: DesignColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (helper.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        helper,
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right,
                  color: DesignColors.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bank Details Bottom Sheet ────────────────────────────────────────

class _BankDetailsSheet extends StatelessWidget {
  const _BankDetailsSheet({required this.method});

  final PaymentMethodModel method;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: DesignColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'Bank transfer details',
            style: DesignTypography.headingM.copyWith(
              fontWeight: FontWeight.w700,
              color: DesignColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Transfer the amount to this bank account and share the receipt with your admin.',
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          _DetailRow(label: 'Bank', value: method.bankName ?? ''),
          _DetailRow(label: 'Account holder', value: method.accountHolderName ?? ''),
          _DetailRow(label: 'Account number', value: method.maskedAccountNumber ?? '', copyable: true),
          _DetailRow(label: 'IFSC code', value: method.ifscCode ?? '', copyable: true),
          _DetailRow(label: 'Account type', value: method.accountType ?? ''),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: DesignColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              style: DesignTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy, size: 16, color: DesignColors.primary),
            ),
        ],
      ),
    );
  }
}
