part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardOverviewCollectionsPart on _MaintenancePaymentScreenState {
  // ───────────────────── Collections hero card ─────────────────────

  Widget _collectionsHeroCard({
    required String periodLabel,
    required double totalExpected,
    required double totalCollected,
    required double totalPending,
    required double totalExpense,
    required double net,
    required int paidCount,
    required int partialCount,
    required int unpaidCount,
    required int overdueCount,
    required NumberFormat inr,
    VoidCallback? onExpensesTap,
  }) {
    final rate =
        totalExpected > 0 ? (totalCollected / totalExpected * 100) : 0.0;
    final rateColor = rate >= 80
        ? DesignColors.success
        : rate >= 50
            ? DesignColors.warning
            : DesignColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Collections', periodLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.surface.defaultSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.surface.border),
              boxShadow: [
                BoxShadow(
                  color: context.text.primary.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status filter chips, top-right — tap to filter residents.
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusCountPill('PAID', '$paidCount', 'Paid',
                              DesignColors.success),
                          if (partialCount > 0)
                            _statusCountPill('PARTIAL', '$partialCount',
                                'Partial', DesignColors.warning),
                          _statusCountPill('UNPAID', '$unpaidCount', 'Unpaid',
                              DesignColors.error),
                          if (overdueCount > 0)
                            _statusCountPill('OVERDUE', '$overdueCount',
                                'Overdue', DesignColors.error),
                        ],
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left — ring + collected / expected
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _collectionRing(rate, rateColor),
                                const SizedBox(height: 14),
                                Text(
                                  'Collected',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: context.text.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inr.format(totalCollected),
                                  style: DesignTypography.headingL.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: context.text.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _targetChip(totalExpected, inr),
                              ],
                            ),
                            const SizedBox(width: 16),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: context.surface.border,
                            ),
                            const SizedBox(width: 16),
                            // Right — icon stat rows
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _collectionStatRow(
                                    icon: Icons.schedule_rounded,
                                    color: DesignColors.warning,
                                    label: 'Pending',
                                    value: inr.format(totalPending),
                                    valueColor: totalPending > 0.005
                                        ? DesignColors.warning
                                        : context.text.primary,
                                    onTap: () => mutateDashboardUi(() =>
                                        _residentStatusFilter = 'UNPAID'),
                                  ),
                                  Divider(
                                    height: 1,
                                    color: context.surface.border
                                        .withValues(alpha: 0.6),
                                  ),
                                  _collectionStatRow(
                                    icon: Icons.south_rounded,
                                    color: DesignColors.info,
                                    label: 'Expenses',
                                    value: inr.format(totalExpense),
                                    valueColor: context.text.primary,
                                    onTap: onExpensesTap ?? _openExpenses,
                                  ),
                                  Divider(
                                    height: 1,
                                    color: context.surface.border
                                        .withValues(alpha: 0.6),
                                  ),
                                  _collectionStatRow(
                                    icon: net >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    color: net >= 0
                                        ? DesignColors.success
                                        : DesignColors.error,
                                    label: 'Net',
                                    value:
                                        '${net >= 0 ? '+' : ''}${inr.format(net)}',
                                    valueColor: net >= 0
                                        ? DesignColors.success
                                        : DesignColors.error,
                                    onTap: onExpensesTap ?? _openExpenses,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _collectionsBanner(net, inr),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One row in the Collections card's right column: tinted icon + label +
  /// coloured value + chevron (the chevron only shows when tappable).
  /// Small tinted "Target ₹X" chip — surfaces the expected-collection figure
  /// next to a collected amount so it doesn't disappear under the hero number.
  Widget _targetChip(double expected, NumberFormat inr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.surface.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.adjust_rounded, size: 13, color: context.text.secondary),
          const SizedBox(width: 5),
          Text(
            'Target ',
            style: DesignTypography.labelSmall.copyWith(
              color: context.text.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            inr.format(expected),
            style: DesignTypography.labelSmall.copyWith(
              color: context.text.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionStatRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.text.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.text.tertiary),
            ],
          ],
        ),
      ),
    );
  }

  /// Contextual footer banner — celebrates a surplus or flags a shortfall.
  Widget _collectionsBanner(double net, NumberFormat inr) {
    final ahead = net >= -0.005;
    final color = PaymentStatusColors.forAdvanceBalance(ahead: ahead);
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              ahead ? Icons.bar_chart_rounded : Icons.warning_amber_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ahead
                  ? "Great job! You're ahead by ${inr.format(net)}"
                  : 'Shortfall of ${inr.format(net.abs())} this period',
              style: DesignTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSocietyExpenses({required int month, required int year}) {
    ref.read(expenseFilterProvider.notifier).state =
        ExpenseFilter(month: month, year: year);
    context.push('/resident/expenses?month=$month&year=$year');
  }

  void _openExpenses() {
    final f = ref.read(maintenanceDashboardFilterProvider);
    _openSocietyExpenses(month: f.month, year: f.year);
  }

  Widget _collectionRing(double rate, Color color) {
    final pct = (rate / 100).clamp(0.0, 1.0);
    const d = 92.0;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: d,
            height: d,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 9,
              valueColor:
                  AlwaysStoppedAnimation<Color>(context.surface.elevated),
            ),
          ),
          SizedBox(
            width: d,
            height: d,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: DesignTypography.headingL.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Collected',
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
