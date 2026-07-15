part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardSharedPart on _MaintenancePaymentScreenState {
  Widget _wrapTabWithRefresh(Widget scrollable) {
    return RefreshIndicator(
      color: DesignColors.primary,
      displacement: 44,
      onRefresh: _pullRefreshMaintenance,
      child: scrollable,
    );
  }

  /// Shimmer placeholder shown while the dashboard loads / a new period is
  /// fetched — far less jarring than a full-screen spinner.
  Widget _buildDashboardSkeleton() {
    Widget box(double h, {double? w, double r = 12}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: context.surface.elevated,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Shimmer.fromColors(
      baseColor: context.surface.elevated,
      highlightColor: context.surface.defaultSurface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Filter row (FY pill + month chips)
          Row(
            children: [
              box(32, w: 92, r: 16),
              const SizedBox(width: 8),
              box(32, w: 60, r: 16),
              const SizedBox(width: 8),
              box(32, w: 60, r: 16),
            ],
          ),
          const SizedBox(height: 18),
          box(150, w: double.infinity, r: 18), // collections hero
          const SizedBox(height: 16),
          box(190, w: double.infinity, r: 16), // where-money chart
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            box(66, w: double.infinity, r: 14), // resident rows
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _cycleReviewStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: context.text.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 12,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Expense breakdown bottom sheet ──

  static const _categoryIcons = <String, IconData>{
    'Electricity': Icons.bolt_rounded,
    'Water': Icons.water_drop_rounded,
    'Garbage Collection': Icons.delete_rounded,
    'Security Salary': Icons.shield_rounded,
    'Housekeeping Salary': Icons.cleaning_services_rounded,
    'Maintenance Staff': Icons.engineering_rounded,
    'Gardening': Icons.yard_rounded,
    'Pest Control': Icons.bug_report_rounded,
    'Lift Maintenance': Icons.elevator_rounded,
    'Generator Maintenance': Icons.power_rounded,
    'Pump Maintenance': Icons.plumbing_rounded,
    'Common Area Repair': Icons.handyman_rounded,
    'Legal Fees': Icons.gavel_rounded,
    'Insurance': Icons.health_and_safety_rounded,
    'Taxes': Icons.receipt_long_rounded,
    'Bank Charges': Icons.account_balance_rounded,
    'Software Subscription': Icons.computer_rounded,
  };

  Color _expenseColor(String category, int index) {
    return ChartPalette.expense(
      category,
      index,
      neutral: context.text.tertiary,
    );
  }

  /// Donut of the expense breakdown ("where your money goes") with the period
  /// total in the centre — same data as the category list beneath it.
  Widget _expenseDonut(
    List<MapEntry<String, double>> entries,
    double total,
    NumberFormat inr,
  ) {
    if (entries.isEmpty || total <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _expenseColor(entries[i].key, i),
                    radius: 13,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                  fontSize: 10,
                ),
              ),
              Text(
                inr.format(total),
                style: DesignTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.text.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExpenseBreakdownSheet(
    BuildContext context, {
    required int month,
    required int year,
    required double totalExpense,
    required Map<String, double> breakdown,
  }) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(year, month));

    // Sort categories by amount descending
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.surface.defaultSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SemanticColors.metaLabelBg(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: SemanticColors.metaLabel,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense breakdown',
                          style: DesignTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          monthLabel,
                          style: DesignTypography.labelSmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: SemanticColors.metaLabelBg(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      inr.format(totalExpense),
                      style: DesignTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: SemanticColors.metaLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: context.text.secondary
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No expense data for this month',
                          style: DesignTypography.bodySmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Category bars
                ...sorted.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value.key;
                  final amount = entry.value.value;
                  final pct =
                      totalExpense > 0 ? (amount / totalExpense * 100) : 0.0;
                  final icon = _categoryIcons[cat] ??
                      Icons.category_rounded;
                  final color = _expenseColor(cat, idx);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 16, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      cat,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DesignTypography.bodySmall
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    inr.format(amount),
                                    style: DesignTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        minHeight: 5,
                                        value: (pct / 100).clamp(0.0, 1.0),
                                        color: color,
                                        backgroundColor:
                                            color.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${pct.toStringAsFixed(0)}%',
                                    style: DesignTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      color: context.text.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.surface.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: context.surface.border),
              ),
              child: Icon(icon, size: 40, color: context.text.secondary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTypography.headingM.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
