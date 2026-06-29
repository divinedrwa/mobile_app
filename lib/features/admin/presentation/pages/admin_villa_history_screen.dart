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

double _readDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? _readDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _readIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

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
    final monthlyAmount = _readDoubleOrNull(villa['monthlyMaintenance']) ??
        _readDoubleOrNull(villa['maintenanceAmount']) ??
        _readDoubleOrNull(data['maintenanceAmount']);

    final stats = (data['statistics'] as Map?) ?? const {};
    final history = ((data['history'] as List?) ??
            (data['payments'] as List?) ??
            const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final totalPaid = _readDoubleOrNull(stats['totalPaid']) ??
        history.fold<double>(
          0,
          (sum, row) => sum + _readDouble(row['paidAmount']),
        );

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
                    label: 'Cycles',
                    value: '${history.length}',
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
          'Billing history',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (history.isEmpty)
          const EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: 'No billing history',
            subtitle:
                'Maintenance cycles and payments for this villa will appear here once billing is generated.',
          )
        else
          for (var i = 0; i < history.length; i++) ...[
            _historyTile(history[i], inr, dateFmt, i),
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

  Widget _historyTile(
    Map<String, dynamic> row,
    NumberFormat inr,
    DateFormat dateFmt, [
    int index = 0,
  ]) {
    final expected = _readDouble(row['amount']);
    final paid = _readDouble(row['paidAmount']);
    final remaining = _readDoubleOrNull(row['remainingDue']) ??
        (expected - paid).clamp(0, double.infinity);
    final status = (row['status']?.toString() ?? '').toUpperCase();
    final mode = row['paymentMode']?.toString() ?? '';
    final paidAt = DateTime.tryParse(
      row['paymentDate']?.toString() ?? row['paidAt']?.toString() ?? '',
    );
    final receiptNumber = row['receiptNumber']?.toString();
    final periodMonth =
        _readIntOrNull(row['month']) ?? _readIntOrNull(row['periodMonth']);
    final periodYear =
        _readIntOrNull(row['year']) ?? _readIntOrNull(row['periodYear']);
    final cycleTitle = row['cycleTitle']?.toString();
    final periodLabel = periodMonth != null && periodYear != null
        ? DateFormat('MMM y').format(DateTime(periodYear, periodMonth))
        : cycleTitle ?? 'Cycle';

    final isPaid = status == 'PAID' || status == 'COMPLETED' || status == 'WAIVED';
    final isPartial = status == 'PARTIAL' ||
        (!isPaid && paid > 0.005 && remaining > 0.005);
    final isOverdue = status == 'OVERDUE';

    final Color statusColor;
    final IconData statusIcon;
    if (isPaid) {
      statusColor = DesignColors.success;
      statusIcon = Icons.check_circle;
    } else if (isOverdue) {
      statusColor = DesignColors.error;
      statusIcon = Icons.warning_amber_rounded;
    } else if (isPartial) {
      statusColor = DesignColors.warning;
      statusIcon = Icons.pie_chart_outline;
    } else {
      statusColor = DesignColors.textTertiary;
      statusIcon = Icons.schedule;
    }

    final amountLabel = isPaid
        ? inr.format(paid > 0 ? paid : expected)
        : isPartial
            ? '${inr.format(paid)} / ${inr.format(expected)}'
            : inr.format(expected);

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
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DesignRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodLabel,
                  style: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    status.replaceAll('_', ' '),
                    if (mode.isNotEmpty) mode,
                    if (paidAt != null) dateFmt.format(paidAt),
                    if (receiptNumber != null) '#$receiptNumber',
                  ].join(' · '),
                  style: DesignTypography.caption.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            amountLabel,
            style: DesignTypography.bodyMedium.copyWith(
              color: isPaid
                  ? DesignColors.success
                  : isOverdue
                      ? DesignColors.error
                      : DesignColors.textPrimary,
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
