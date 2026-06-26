import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Payment history for a single villa — admin view.
class AdminVillaHistoryScreen extends ConsumerWidget {
  const AdminVillaHistoryScreen({super.key, required this.villaId});

  final String villaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(adminVillaHistoryProvider(villaId));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Villa history',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: () =>
                ref.invalidate(adminVillaHistoryProvider(villaId)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () async {
          ref.invalidate(adminVillaHistoryProvider(villaId));
          await ref.read(adminVillaHistoryProvider(villaId).future);
        },
        child: historyAsync.when(
          loading: () => _buildSkeleton(),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              EmptyStateWidget(
                icon: Icons.cloud_off_outlined,
                title: 'Something went wrong',
                subtitle: 'Could not load data.\nPull down to retry.',
              ),
            ],
          ),
          data: (data) => _buildContent(context, data),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final inr =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y');

    final villa = (data['villa'] as Map?) ?? const {};
    final villaNumber = villa['villaNumber']?.toString() ??
        data['villaNumber']?.toString() ??
        '—';
    final block = villa['block']?.toString() ?? data['block']?.toString();
    final ownerName = villa['ownerName']?.toString() ??
        data['ownerName']?.toString() ??
        'Unknown';
    final monthlyAmount =
        (villa['maintenanceAmount'] as num?)?.toDouble() ??
            (data['maintenanceAmount'] as num?)?.toDouble();

    final payments = ((data['payments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final totalPaid = (data['totalPaid'] as num?)?.toDouble() ??
        payments.fold<double>(
            0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        // Villa header
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      villaNumber,
                      style: DesignTypography.headingM.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Villa $villaNumber${block != null ? ' · $block' : ''}',
                          style: DesignTypography.bodyMedium.copyWith(
                            color: DesignColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ownerName,
                          style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _statBadge(
                    label: 'Total paid',
                    value: inr.format(totalPaid),
                    color: DesignColors.success,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (monthlyAmount != null)
                    _statBadge(
                      label: 'Monthly',
                      value: inr.format(monthlyAmount),
                      color: DesignColors.primary,
                    ),
                  const SizedBox(width: AppSpacing.md),
                  _statBadge(
                    label: 'Payments',
                    value: '${payments.length}',
                    color: DesignColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // History list
        Text(
          'Payment history',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (payments.isEmpty)
          const EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            subtitle: 'Payment history will appear here once payments are recorded.',
          )
        else
          for (var i = 0; i < payments.length; i++) ...[
            _paymentTile(payments[i], inr, dateFmt, i),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Widget _statBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: DesignTypography.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: DesignTypography.caption.copyWith(
                color: DesignColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(
    Map<String, dynamic> p,
    NumberFormat inr,
    DateFormat dateFmt, [
    int index = 0,
  ]) {
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final status = (p['status']?.toString() ?? '').toUpperCase();
    final mode = p['paymentMode']?.toString() ?? '';
    final paidAt = DateTime.tryParse(p['paidAt']?.toString() ?? '');
    final receiptNumber = p['receiptNumber']?.toString();
    final periodMonth = (p['periodMonth'] as num?)?.toInt();
    final periodYear = (p['periodYear'] as num?)?.toInt();
    final periodLabel = periodMonth != null && periodYear != null
        ? DateFormat('MMM y').format(DateTime(periodYear, periodMonth))
        : null;

    final isPaid = status == 'PAID' || status == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        border: Border.all(color: DesignColors.borderLight),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPaid
                  ? DesignColors.success.withValues(alpha: 0.12)
                  : DesignColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DesignRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              isPaid ? Icons.check_circle : Icons.schedule,
              size: 18,
              color: isPaid ? DesignColors.success : DesignColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodLabel ?? 'Payment',
                  style: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (mode.isNotEmpty) mode,
                    if (paidAt != null) dateFmt.format(paidAt),
                    if (receiptNumber != null) '#$receiptNumber',
                  ].join(' · '),
                  style: DesignTypography.caption.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            inr.format(amount),
            style: DesignTypography.bodyMedium.copyWith(
              color: isPaid ? DesignColors.success : DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  Widget _buildSkeleton() {
    return ShimmerWrap(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          ShimmerBox(height: 140, borderRadius: DesignRadius.xl),
          const SizedBox(height: AppSpacing.xl),
          for (int i = 0; i < 6; i++) ...[
            ShimmerBox(height: 68, borderRadius: DesignRadius.lg),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
