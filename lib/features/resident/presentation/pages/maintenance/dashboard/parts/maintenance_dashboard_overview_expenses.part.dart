part of '../maintenance_payment_screen.dart';
extension _MaintenanceDashboardOverviewExpensesPart on _MaintenancePaymentScreenState {
  Widget _buildOverviewExpenseSection(
    Map<String, dynamic> expenses,
    double totalExpense,
    int totalResidents,
    String periodLabel,
    int periodMonth,
    int periodYear,
    NumberFormat inr,
  ) {
    return Builder(
      builder: (_) {
        final raw = expenses['categoryBreakdown'];
        if (raw is! Map) return const SizedBox.shrink();
        final entries = <MapEntry<String, double>>[];
        raw.forEach((k, v) {
          final key = k.toString();
          final val = (v is num)
              ? v.toDouble()
              : double.tryParse(v.toString()) ?? 0;
          if (val > 0) entries.add(MapEntry(key, val));
        });
        if (entries.isEmpty) return const SizedBox.shrink();
        entries.sort((a, b) => b.value.compareTo(a.value));
        // Reconcile the printed total with the rows shown: if the
        // backend total exceeds the categorized sum, surface the
        // remainder as "Other" so the column always adds up.
        final entriesSum =
            entries.fold<double>(0, (s, e) => s + e.value);
        final displayTotal =
            totalExpense > entriesSum ? totalExpense : entriesSum;
        if (displayTotal - entriesSum > 0.5) {
          entries.add(MapEntry('Other', displayTotal - entriesSum));
        }
        // Per-home share — what each home effectively funds this period.
        final perHome =
            totalResidents > 0 ? displayTotal / totalResidents : 0.0;
        final expenseSubtitle = perHome > 0
            ? '≈ ${inr.format(perHome)}/home'
            : periodLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Where your money goes', expenseSubtitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surface.defaultSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.surface.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Donut (centre shows the total) + a compact
                      // top-5 legend; full breakdown via the link below.
                      _expenseDonut(entries, displayTotal, inr),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0;
                                i < entries.length && i < 5;
                                i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: _expenseColor(
                                            entries[i].key, i),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entries[i].key.replaceAll('_', ' '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: DesignTypography.labelSmall
                                            .copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: context.text.secondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      inr.format(entries[i].value),
                                      style: DesignTypography.labelSmall
                                          .copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: context.text.primary,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${(entries[i].value / displayTotal * 100).toStringAsFixed(0)}%',
                                      style: DesignTypography.labelSmall
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: context.text.tertiary,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (entries.length > 5)
                              Text(
                                '+${entries.length - 5} more',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: context.text.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Hide society expenses link from tenants.
            if (!ref.watch(authProvider
                .select((s) => s.user?.isTenant ?? false))) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () => _openSocietyExpenses(
                      month: periodMonth, year: periodYear),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.surface.defaultSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.surface.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: DesignColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'View all society expenses',
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: DesignColors.primary.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

  }
}
