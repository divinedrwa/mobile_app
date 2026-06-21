import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/screen_skeletons.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../data/models/expense_breakdown_model.dart';
import '../../../data/providers/maintenance_provider.dart';

/// Parses a billing-cycle map's month/year. The backend exposes the period as
/// `cycleKey` ("YYYY-MM") (sometimes `periodMonth`/`periodYear`), not plain
/// `month`/`year` — so derive it the same way the rest of the app does.
({int month, int year}) _cycleMonthYear(Map<String, dynamic> c) {
  int month = (c['month'] as num?)?.toInt() ?? 0;
  int year = (c['year'] as num?)?.toInt() ?? 0;
  if (month < 1 || year < 1) {
    final key = c['cycleKey']?.toString() ?? '';
    final parts = key.split('-');
    if (parts.length >= 2) {
      year = int.tryParse(parts[0]) ?? year;
      month = int.tryParse(parts[1]) ?? month;
    }
  }
  if (month < 1) month = (c['periodMonth'] as num?)?.toInt() ?? month;
  if (year < 1) year = (c['periodYear'] as num?)?.toInt() ?? year;
  return (month: month, year: year);
}

/// "Where your money goes" — the resident's per-home view of their maintenance
/// for a billing cycle: each society expense ÷ paying (non-excluded) homes,
/// plus the leftover saved to reserves. A chip opens an FY + cycle picker.
class WhereMoneyGoesCard extends ConsumerWidget {
  const WhereMoneyGoesCard({super.key});

  static const _palette = <Color>[
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];
  static const _savingsColor = Color(0xFF94A3B8);
  static final _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(residentExpenseBreakdownProvider);
    final selection = ref.watch(selectedExpenseCycleProvider);
    final data = async.valueOrNull;
    final hasData = data != null && data.hasData;

    // Hide entirely only in the default/auto state with nothing to show. Once
    // the resident has picked a cycle, keep the card (and its chip) visible so
    // they can switch cycles even if the chosen one has no expenses.
    if (!hasData && selection == null) return const SizedBox.shrink();

    final inr = _inr;

    // Month shown on the chip: the data's month if loaded, else the selection's.
    final labelMonth = hasData ? data.month : (selection?.month ?? 0);
    final labelYear = hasData ? data.year : (selection?.year ?? 0);
    final monthLabel = (labelMonth >= 1 && labelMonth <= 12)
        ? DateFormat('MMM y').format(DateTime(labelYear, labelMonth))
        : 'Cycle';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- header ----
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: DesignColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    size: 16, color: DesignColors.warning),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Where your money goes',
                  style: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openPicker(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: DesignColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DesignColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Text(
                        monthLabel,
                        style: DesignTypography.caption.copyWith(
                          color: DesignColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.expand_more,
                          size: 16, color: DesignColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // ---- body ----
          if (hasData)
            ..._content(data, inr)
          else if (async.isLoading)
            const _BodySkeleton()
          else
            _emptyBody(ref),
        ],
      ),
    );
  }

  List<Widget> _content(ExpenseBreakdown data, NumberFormat inr) {
    final members = data.memberCount;
    final hasSplit = members > 0;
    final perExpenses = data.perMemberTotal; // expenses ÷ homes
    final perHome = data.perHomeExpected; // maintenance you pay ÷ homes
    final hasMaint = hasSplit && perHome > 0;
    final net = perHome - perExpenses; // + surplus to reserves / − from reserves
    final surplus = hasMaint && net > 0.5;
    final deficit = hasMaint && net < -0.5;

    // In surplus the donut shows your full maintenance (expenses + a reserve
    // slice); otherwise it shows the expense split only.
    final showSavings = surplus;
    final pieBasis = showSavings ? data.totalExpected : data.categoriesTotal;
    final centerValue =
        showSavings ? perHome : (hasSplit ? perExpenses : data.total);
    final centerLabel = showSavings
        ? 'You pay'
        : (hasMaint ? 'Cost / home' : (hasSplit ? 'Your share' : 'Total'));
    final savingsSlice = data.totalExpected - data.categoriesTotal;
    final categories = data.categories;

    return [
      Text(
        surplus
            ? 'Your ${inr.format(perHome)} maintenance this cycle — where it goes.'
            : hasMaint
                ? 'Society spent ${inr.format(data.categoriesTotal)} this cycle across $members homes.'
                : hasSplit
                    ? 'Your share of ${inr.format(data.categoriesTotal)} spent this cycle, split across $members homes.'
                    : 'Society spending this cycle.',
        style: DesignTypography.caption
            .copyWith(color: DesignColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    startDegreeOffset: -90,
                    sections: [
                      for (var i = 0; i < categories.length; i++)
                        PieChartSectionData(
                          value: categories[i].amount,
                          color: _palette[i % _palette.length],
                          radius: 18,
                          showTitle: false,
                        ),
                      if (showSavings && savingsSlice > 0)
                        PieChartSectionData(
                          value: savingsSlice,
                          color: _savingsColor,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      inr.format(centerValue),
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  _LegendRow(
                    color: _palette[i % _palette.length],
                    label: categories[i].name,
                    amount: inr.format(hasSplit
                        ? categories[i].perMember(members)
                        : categories[i].amount),
                    percent: categories[i].percentOf(pieBasis),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (showSavings)
                  _LegendRow(
                    color: _savingsColor,
                    label: 'Saved to reserve',
                    amount: inr.format(net),
                    percent: pieBasis > 0 ? (savingsSlice / pieBasis) * 100 : 0,
                  ),
              ],
            ),
          ),
        ],
      ),
      if (hasSplit) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          surplus
              ? 'You pay ${inr.format(perHome)} · ${inr.format(net)} saved to society reserves.'
              : deficit
                  ? 'You pay ${inr.format(perHome)} · expenses were ${inr.format(-net)}/home more, covered by reserves.'
                  : hasMaint
                      ? 'You pay ${inr.format(perHome)} — fully used by this cycle\'s expenses.'
                      : 'Each expense ÷ $members homes.',
          style: DesignTypography.captionSmall
              .copyWith(color: DesignColors.textTertiary),
        ),
      ],
    ];
  }

  Widget _emptyBody(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 28, color: DesignColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No expenses recorded for this cycle yet.',
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall
                .copyWith(color: DesignColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () =>
                ref.read(selectedExpenseCycleProvider.notifier).state = null,
            child: Text(
              'Show latest cycle',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CyclePickerSheet(),
    );
  }
}

/// Skeleton for the card body: mirrors the donut chart + legend rows shown
/// once the expense breakdown loads.
class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) {
    return const ShimmerWrap(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(height: 12, borderRadius: 6, width: 200),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                ShimmerBox(width: 104, height: 104, borderRadius: 52),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 14, borderRadius: 6),
                      SizedBox(height: AppSpacing.sm),
                      ShimmerBox(height: 14, borderRadius: 6),
                      SizedBox(height: AppSpacing.sm),
                      ShimmerBox(height: 14, borderRadius: 6, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.amount,
    required this.percent,
  });

  final Color color;
  final String label;
  final String amount;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          amount,
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(${percent.toStringAsFixed(1)}%)',
          style: DesignTypography.caption
              .copyWith(color: DesignColors.textTertiary),
        ),
      ],
    );
  }
}

/// Bottom sheet: pick a financial year, then a billing cycle within it.
class _CyclePickerSheet extends ConsumerStatefulWidget {
  const _CyclePickerSheet();

  @override
  ConsumerState<_CyclePickerSheet> createState() => _CyclePickerSheetState();
}

class _CyclePickerSheetState extends ConsumerState<_CyclePickerSheet> {
  String? _fyId;

  @override
  void initState() {
    super.initState();
    _fyId = ref.read(selectedExpenseCycleProvider)?.financialYearId;
  }

  @override
  Widget build(BuildContext context) {
    final fysAsync = ref.watch(billingFinancialYearsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose billing cycle',
              style: DesignTypography.bodyMedium.copyWith(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _OptionTile(
              icon: Icons.auto_awesome_outlined,
              label: 'Current / latest cycle',
              selected: ref.watch(selectedExpenseCycleProvider) == null,
              onTap: () {
                ref.read(selectedExpenseCycleProvider.notifier).state = null;
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: AppSpacing.lg),
            fysAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: PickerSkeleton(itemCount: 3),
              ),
              error: (_, _) => Text(
                'Couldn\'t load financial years.',
                style: DesignTypography.bodySmall
                    .copyWith(color: DesignColors.error),
              ),
              data: (fys) {
                if (fys.isEmpty) {
                  return Text(
                    'No financial years available.',
                    style: DesignTypography.bodySmall
                        .copyWith(color: DesignColors.textSecondary),
                  );
                }
                _fyId ??= fys.last['id']?.toString();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FINANCIAL YEAR',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textTertiary,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fys.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final fy = fys[i];
                          final id = fy['id']?.toString();
                          final active = id == _fyId;
                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => setState(() => _fyId = id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: active
                                    ? DesignColors.primary
                                    : DesignColors.surface,
                                border: Border.all(
                                    color: active
                                        ? DesignColors.primary
                                        : DesignColors.borderLight),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                fy['label']?.toString() ?? 'Year',
                                style: DesignTypography.bodySmall.copyWith(
                                  color: active
                                      ? Colors.white
                                      : DesignColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_fyId != null) _cycleList(_fyId!),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cycleList(String fyId) {
    final cyclesAsync = ref.watch(billingCyclesForFinancialYearProvider(fyId));
    return cyclesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: PickerSkeleton(itemCount: 4),
      ),
      error: (_, _) => Text(
        'Couldn\'t load cycles.',
        style: DesignTypography.bodySmall.copyWith(color: DesignColors.error),
      ),
      data: (body) {
        final raw = body['cycles'];
        final cycles = raw is List
            ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        if (cycles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'No billing cycles created for this year.',
              style: DesignTypography.bodySmall
                  .copyWith(color: DesignColors.textSecondary),
            ),
          );
        }
        cycles.sort((a, b) {
          final ma = _cycleMonthYear(a);
          final mb = _cycleMonthYear(b);
          if (ma.year != mb.year) return mb.year.compareTo(ma.year);
          return mb.month.compareTo(ma.month);
        });
        final current = ref.watch(selectedExpenseCycleProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BILLING CYCLE',
                style: DesignTypography.captionSmall.copyWith(
                  color: DesignColors.textTertiary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in cycles) _cycleTile(fyId, c, current),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cycleTile(
      String fyId, Map<String, dynamic> c, ExpenseCycleSelection? current) {
    final id = c['id']?.toString() ?? '';
    final my = _cycleMonthYear(c);
    final label = (my.month >= 1 && my.month <= 12)
        ? DateFormat('MMMM y').format(DateTime(my.year, my.month))
        : (c['cycleKey']?.toString() ?? 'Cycle');
    final selected = current?.billingCycleId == id;
    return _OptionTile(
      icon: Icons.calendar_today_outlined,
      label: label,
      selected: selected,
      onTap: (id.isEmpty || my.month < 1 || my.year < 1)
          ? null
          : () {
              ref.read(selectedExpenseCycleProvider.notifier).state =
                  ExpenseCycleSelection(
                financialYearId: fyId,
                billingCycleId: id,
                month: my.month,
                year: my.year,
              );
              Navigator.of(context).pop();
            },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DesignRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? DesignColors.primary
                    : DesignColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  size: 18, color: DesignColors.primary),
          ],
        ),
      ),
    );
  }
}
