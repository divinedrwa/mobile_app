part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardShortfallPart on _MaintenancePaymentScreenState {
  Widget _buildShortfallTab(BuildContext context) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    final filter = ref.watch(maintenanceDashboardFilterProvider);

    final fyId = filter.financialYearId;
    final cyclesAsync = fyId != null && fyId.isNotEmpty
        ? ref.watch(billingCyclesForFinancialYearProvider(fyId))
        : null;

    if (cyclesAsync == null) {
      return _wrapTabWithRefresh(
        Center(
          child: _emptyState(
            icon: Icons.calendar_today_outlined,
            title: 'Select a financial year',
            subtitle: 'Choose a financial year from the dropdown above to view shortfall data.',
          ),
        ),
      );
    }

    return cyclesAsync.when(
      loading: () => const ListSkeleton(itemHeight: 100),
      error: (e, _) => _wrapTabWithRefresh(
        Center(
          child: _emptyState(
            icon: Icons.error_outline,
            title: 'Failed to load data',
            subtitle: e.toString(),
          ),
        ),
      ),
      data: (body) {
        final rawCycles = body['cycles'];
        final cycles = rawCycles is List
            ? rawCycles.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        // Determine calendar years spanned by this FY's cycles
        final neededYears = <int>{};
        for (final c in cycles) {
          final my = monthYearFromCycleKey(c['cycleKey']?.toString() ?? '');
          if (my != null) neededYears.add(my.year);
        }

        // Fetch yearlyBreakdown for each calendar year
        final breakdownByKey = <String, Map<String, dynamic>>{};
        bool allYearsLoaded = true;
        Object? yearLoadError;
        for (final yr in neededYears) {
          final yrAsync = ref.watch(yearlyBreakdownForYearProvider(yr));
          yrAsync.whenData((rows) {
            for (final row in rows) {
              final m = (row['month'] as num?)?.toInt() ?? 0;
              final y = (row['year'] as num?)?.toInt() ?? 0;
              if (m > 0 && y > 0) {
                breakdownByKey['$y-${m.toString().padLeft(2, '0')}'] = row;
              }
            }
          });
          if (yrAsync is AsyncError) {
            yearLoadError ??= yrAsync.error;
          } else if (yrAsync is! AsyncData) {
            allYearsLoaded = false;
          }
        }

        // A failed year breakdown surfaces an error with retry — otherwise the
        // loading guard below would spin forever (it never sees AsyncData).
        if (yearLoadError != null) {
          return _yearDataErrorState(yearLoadError);
        }

        if (!allYearsLoaded && neededYears.isNotEmpty) {
          return const ListSkeleton(itemHeight: 100);
        }

        // Build per-cycle rows with financial data
        // Mirrors Year Review's totalExpected validation: use
        // breakdown values only when totalExpected > 0, otherwise
        // fall back to the cycle's configured amount.
        final allRows = <Map<String, dynamic>>[];
        for (final c in cycles) {
          final cycleKey = c['cycleKey']?.toString() ?? '';
          final my = monthYearFromCycleKey(cycleKey);
          final breakdown = breakdownByKey[cycleKey];
          final cycleAmount = (c['amount'] as num?)?.toDouble() ?? 0;

          double mExp, mColl, mExpense;
          if (breakdown != null &&
              ((breakdown['totalExpected'] as num?)?.toDouble() ?? 0) > 0) {
            mExp = (breakdown['totalExpected'] as num?)?.toDouble() ?? 0;
            mColl = (breakdown['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown['totalExpense'] as num?)?.toDouble() ?? 0;
          } else {
            // `cycleAmount` is the per-villa charge — scale by billed-villa
            // count so Expected matches the society-wide Collected scale.
            final paidC = (breakdown?['paidCount'] as num?)?.toInt() ?? 0;
            final unpaidC = (breakdown?['unpaidCount'] as num?)?.toInt() ?? 0;
            final villaCount = paidC + unpaidC;
            mExp = villaCount > 0 ? cycleAmount * villaCount : 0;
            mColl = (breakdown?['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown?['totalExpense'] as num?)?.toDouble() ?? 0;
          }
          final net = mColl - mExpense;

          // Extract expense breakdown by category
          final rawBreakdown = breakdown?['expenseBreakdown'];
          final expenseBreakdown = <String, double>{};
          if (rawBreakdown is Map) {
            for (final entry in rawBreakdown.entries) {
              final val = (entry.value as num?)?.toDouble() ?? 0;
              if (val > 0) expenseBreakdown[entry.key.toString()] = val;
            }
          }

          allRows.add({
            'month': my?.month ?? 0,
            'year': my?.year ?? 0,
            'cycleKey': cycleKey,
            'totalExpected': mExp,
            'totalCollected': mColl,
            'totalExpense': mExpense,
            'net': net,
            'expenseBreakdown': expenseBreakdown,
          });
        }

        // Filter to deficit months only (where expenses > collected)
        final deficitRows = allRows.where((r) => ((r['net'] as num?)?.toDouble() ?? 0) < 0).toList();

        // Aggregated totals across ALL months
        double totalExpected = 0;
        double totalCollected = 0;
        double totalExpense = 0;
        for (final row in allRows) {
          totalExpected += (row['totalExpected'] as num?)?.toDouble() ?? 0;
          totalCollected += (row['totalCollected'] as num?)?.toDouble() ?? 0;
          totalExpense += (row['totalExpense'] as num?)?.toDouble() ?? 0;
        }

        // Total shortfall = sum of |net| for deficit months only
        final totalShortfall = deficitRows.fold<double>(
          0, (sum, r) => sum + ((r['net'] as num?)?.toDouble() ?? 0).abs(),
        );

        return _wrapTabWithRefresh(
          ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── FY-level summary card ──
              _shortfallSummaryCard(
                totalExpected: totalExpected,
                totalCollected: totalCollected,
                totalExpense: totalExpense,
                totalShortfall: totalShortfall,
                deficitCount: deficitRows.length,
                totalCycles: allRows.length,
                inr: inr,
              ),

              const SizedBox(height: 18),

              if (deficitRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DesignColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle_outline_rounded, size: 48, color: DesignColors.success),
                      ),
                      const SizedBox(height: 16),
                      Text('No deficit months',
                        style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Collections covered expenses in every billing cycle this year.',
                        textAlign: TextAlign.center,
                        style: DesignTypography.bodySmall.copyWith(color: context.text.secondary, height: 1.4),
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Deficit months',
                    style: DesignTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in deficitRows) _shortfallMonthCard(row, inr),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shortfallSummaryCard({
    required double totalExpected,
    required double totalCollected,
    required double totalExpense,
    required double totalShortfall,
    required int deficitCount,
    required int totalCycles,
    required NumberFormat inr,
  }) {
    final hasDeficit = deficitCount > 0;
    final heroColor = PaymentStatusColors.forDeficitHero(hasDeficit: hasDeficit);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Shortfall',
                    style: DesignTypography.labelSmall.copyWith(
                      color: context.text.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalCycles cycle${totalCycles == 1 ? '' : 's'}',
                      style: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                hasDeficit ? inr.format(totalShortfall) : inr.format(0),
                style: DesignTypography.headingL.copyWith(
                  color: heroColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasDeficit
                    ? 'Extra paid by admin across $deficitCount deficit month${deficitCount == 1 ? '' : 's'}'
                    : 'Collections covered all expenses',
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: context.surface.border.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 2),
              _collectionStatRow(
                icon: Icons.adjust_rounded,
                color: DesignColors.primary,
                label: 'Expected',
                value: inr.format(totalExpected),
                valueColor: context.text.primary,
              ),
              Divider(
                height: 1,
                color: context.surface.border.withValues(alpha: 0.6),
              ),
              _collectionStatRow(
                icon: Icons.check_circle_outline_rounded,
                color: DesignColors.success,
                label: 'Collected',
                value: inr.format(totalCollected),
                valueColor: DesignColors.success,
              ),
              Divider(
                height: 1,
                color: context.surface.border.withValues(alpha: 0.6),
              ),
              _collectionStatRow(
                icon: Icons.south_rounded,
                color: DesignColors.info,
                label: 'Expenses',
                value: inr.format(totalExpense),
                valueColor: context.text.primary,
              ),
              if (hasDeficit) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: DesignColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Shortfall = sum of (expenses − collected) for months where expenses exceeded collections'
                    '${deficitCount > 1 ? ' · Avg ${inr.format(totalShortfall / deficitCount)}/mo' : ''}',
                    style: DesignTypography.labelSmall.copyWith(
                      color: DesignColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortfallMonthCard(Map<String, dynamic> row, NumberFormat inr) {
    final m = (row['month'] as num?)?.toInt() ?? 1;
    final yr = (row['year'] as num?)?.toInt() ?? DateTime.now().year;
    final mColl = (row['totalCollected'] as num?)?.toDouble() ?? 0;
    final mExpense = (row['totalExpense'] as num?)?.toDouble() ?? 0;
    final mExp = (row['totalExpected'] as num?)?.toDouble() ?? 0;
    final net = (row['net'] as num?)?.toDouble() ?? 0;
    final shortfall = net.abs();
    final breakdown = (row['expenseBreakdown'] as Map<String, double>?) ?? const <String, double>{};
    final isExpanded = _expandedShortfallMonths.contains(m * 100 + yr);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.surface.border),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => mutateDashboardUi(() {
                final key = m * 100 + yr;
                if (isExpanded) { _expandedShortfallMonths.remove(key); }
                else { _expandedShortfallMonths.add(key); }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(DateTime(yr, m)),
                          style: DesignTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SemanticColors.warningSurface(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '−${inr.format(shortfall)}',
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.error, fontWeight: FontWeight.w800, fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18, color: context.text.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _cycleReviewStat('Expected', inr.format(mExp), DesignColors.primary),
                        _cycleReviewStat('Collected', inr.format(mColl), DesignColors.success),
                        _cycleReviewStat('Expenses', inr.format(mExpense), DesignColors.error),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Expanded expense breakdown
            if (isExpanded && breakdown.isNotEmpty) ...[
              Divider(height: 1, thickness: 1, color: context.surface.border.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expense breakdown', style: DesignTypography.labelSmall.copyWith(
                      color: context.text.secondary, fontWeight: FontWeight.w700, fontSize: 10,
                      letterSpacing: 0.3,
                    )),
                    const SizedBox(height: 6),
                    for (final entry in breakdown.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.key, style: DesignTypography.bodySmall.copyWith(
                              color: context.text.secondary, fontWeight: FontWeight.w500, fontSize: 12,
                            ))),
                            Text(inr.format(entry.value), style: DesignTypography.bodySmall.copyWith(
                              color: context.text.primary, fontWeight: FontWeight.w600, fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SemanticColors.warningSurface(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Shortfall (admin paid)', style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.warning, fontWeight: FontWeight.w700,
                          )),
                          Text(inr.format(shortfall), style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.warning, fontWeight: FontWeight.w800,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
