part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardYearReviewPart on _MaintenancePaymentScreenState {
  Widget _buildYearReviewTab(
    BuildContext context,
    MaintenanceDashboardFilter filter,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

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
            subtitle: 'Choose a financial year from the dropdown above.',
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
            title: 'Failed to load cycles',
            subtitle: e.toString(),
          ),
        ),
      ),
      data: (body) {
        final rawCycles = body['cycles'];
        final cycles = rawCycles is List
            ? rawCycles
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        // Determine which calendar years the FY's cycles span.
        final neededYears = <int>{};
        for (final c in cycles) {
          final my = monthYearFromCycleKey(c['cycleKey']?.toString() ?? '');
          if (my != null) neededYears.add(my.year);
        }

        // Fetch yearlyBreakdown for each calendar year and merge
        // into a single lookup keyed by "YYYY-MM".
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

        // Show loading if year breakdowns haven't arrived yet.
        if (!allYearsLoaded && neededYears.isNotEmpty) {
          return const ListSkeleton(itemHeight: 100);
        }

        // Build cycle rows with financial data.
        final cycleRows = <Map<String, dynamic>>[];
        for (final c in cycles) {
          final cycleKey = c['cycleKey']?.toString() ?? '';
          final my = monthYearFromCycleKey(cycleKey);
          final breakdown = breakdownByKey[cycleKey];
          final cycleAmount = (c['amount'] as num?)?.toDouble() ?? 0;

          double mExp, mColl, mExpense;
          int paidC, unpaidC;
          if (breakdown != null &&
              ((breakdown['totalExpected'] as num?)?.toDouble() ?? 0) > 0) {
            mExp = (breakdown['totalExpected'] as num?)?.toDouble() ?? 0;
            mColl = (breakdown['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown['totalExpense'] as num?)?.toDouble() ?? 0;
            paidC = (breakdown['paidCount'] as num?)?.toInt() ?? 0;
            unpaidC = (breakdown['unpaidCount'] as num?)?.toInt() ?? 0;
          } else {
            paidC = (breakdown?['paidCount'] as num?)?.toInt() ?? 0;
            unpaidC = (breakdown?['unpaidCount'] as num?)?.toInt() ?? 0;
            // `cycleAmount` is the per-villa charge, not a society-wide total —
            // scale it by the billed-villa count so Expected and the collection
            // rate stay on the same scale as Collected. When the count is
            // unknown, leave Expected at 0 rather than show a per-villa figure
            // against society-wide collections (which inflates the rate).
            final villaCount = paidC + unpaidC;
            mExp = villaCount > 0 ? cycleAmount * villaCount : 0;
            mColl = (breakdown?['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown?['totalExpense'] as num?)?.toDouble() ?? 0;
          }

          // Extract expense breakdown by category
          final rawBreakdown = breakdown?['expenseBreakdown'];
          final expenseBreakdown = <String, double>{};
          if (rawBreakdown is Map) {
            for (final entry in rawBreakdown.entries) {
              final val = (entry.value as num?)?.toDouble() ?? 0;
              if (val > 0) expenseBreakdown[entry.key.toString()] = val;
            }
          }

          cycleRows.add({
            'month': my?.month ?? 0,
            'year': my?.year ?? 0,
            'cycleKey': cycleKey,
            'amount': cycleAmount,
            'totalExpected': mExp,
            'totalCollected': mColl,
            'totalExpense': mExpense,
            'paidCount': paidC,
            'unpaidCount': unpaidC,
            'expenseBreakdown': expenseBreakdown,
          });
        }

        // Aggregate totals
        double totalExpected = 0;
        double totalCollected = 0;
        double totalExpense = 0;
        for (final row in cycleRows) {
          totalExpected += (row['totalExpected'] as num?)?.toDouble() ?? 0;
          totalCollected += (row['totalCollected'] as num?)?.toDouble() ?? 0;
          totalExpense += (row['totalExpense'] as num?)?.toDouble() ?? 0;
        }
        final totalPending =
            (totalExpected - totalCollected).clamp(0.0, double.infinity);
        final collectionRate =
            totalExpected > 0 ? (totalCollected / totalExpected * 100) : 0.0;
        final rateColor =
            PaymentStatusColors.forCollectionRate(collectionRate);

        return _wrapTabWithRefresh(
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Year summary card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                              'Year review',
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
                                color: DesignColors.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cycleRows.length} cycle${cycleRows.length == 1 ? '' : 's'}',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: DesignColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _collectionRing(collectionRate, rateColor),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Collected',
                                    style: DesignTypography.labelSmall.copyWith(
                                      color: context.text.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                ),
              ),

              const SizedBox(height: 18),

              // ── Billing cycles list ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Billing cycles',
                  style: DesignTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (cycleRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.surface.defaultSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.surface.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 40,
                          color: context.text.secondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No billing cycles in this year',
                          style: DesignTypography.bodySmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...cycleRows.map((row) {
                  final m = (row['month'] as num?)?.toInt() ?? 1;
                  final yr = (row['year'] as num?)?.toInt() ?? filter.year;
                  final mExp = (row['totalExpected'] as num?)?.toDouble() ?? 0;
                  final mColl = (row['totalCollected'] as num?)?.toDouble() ?? 0;
                  final mPending = (mExp - mColl).clamp(0.0, double.infinity);
                  final mExpense = (row['totalExpense'] as num?)?.toDouble() ?? 0;
                  final mNet = mColl - mExpense;
                  final mNetColor =
                      mNet >= 0 ? PaymentStatusColors.forNetBalance(mNet) : DesignColors.error;
                  final paidC = (row['paidCount'] as num?)?.toInt() ?? 0;
                  final unpaidC = (row['unpaidCount'] as num?)?.toInt() ?? 0;
                  final mRate = mExp > 0 ? (mColl / mExp * 100) : 0.0;
                  final mRateColor = mRate >= 80
                      ? DesignColors.success
                      : mRate >= 50
                          ? DesignColors.warning
                          : DesignColors.error;
                  final isCurrentMonth =
                      m == DateTime.now().month && yr == DateTime.now().year;
                  final breakdown =
                      (row['expenseBreakdown'] as Map<String, double>?) ??
                          const <String, double>{};

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: GestureDetector(
                      onTap: () => _showExpenseBreakdownSheet(
                        context,
                        month: m,
                        year: yr,
                        totalExpense: mExpense,
                        breakdown: breakdown,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.surface.defaultSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentMonth
                                ? DesignColors.primary.withValues(alpha: 0.5)
                                : context.surface.border,
                            width: isCurrentMonth ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat('MMMM yyyy')
                                        .format(DateTime(yr, m)),
                                    style: DesignTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (isCurrentMonth) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: DesignColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: DesignTypography.labelSmall.copyWith(
                                          color: DesignColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    '$paidC paid · $unpaidC unpaid',
                                    style: DesignTypography.labelSmall.copyWith(
                                      color: context.text.secondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: context.text.secondary
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _cycleReviewStat(
                                      'Expected', inr.format(mExp), DesignColors.primary),
                                  _cycleReviewStat(
                                      'Collected', inr.format(mColl), DesignColors.success),
                                  _cycleReviewStat(
                                      'Pending', inr.format(mPending), DesignColors.error),
                                  _cycleReviewStat(
                                      'Expenses', inr.format(mExpense), SemanticColors.metaLabel),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        minHeight: 5,
                                        value: (mRate / 100).clamp(0.0, 1.0),
                                        color: mRateColor,
                                        backgroundColor: context.surface.elevated,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${mRate.toStringAsFixed(0)}%',
                                    style: DesignTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      color: mRateColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Net for this cycle = collected − expenses.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: mNetColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      mNet >= 0
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_down_rounded,
                                      size: 14,
                                      color: mNetColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Net (collected − expenses)',
                                      style:
                                          DesignTypography.labelSmall.copyWith(
                                        color: context.text.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${mNet >= 0 ? '+' : ''}${inr.format(mNet)}',
                                      style:
                                          DesignTypography.labelSmall.copyWith(
                                        color: mNetColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
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
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
