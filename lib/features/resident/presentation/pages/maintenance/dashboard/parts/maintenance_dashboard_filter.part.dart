part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardFilterPart on _MaintenancePaymentScreenState {
  Widget _buildStickyFilterBar(
    BuildContext context,
    MaintenanceDashboardFilter filter,
    Map<String, dynamic> dashboard, {
    bool hidesCycleDropdown = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.surface.border),
    );
    final fyAsync = ref.watch(billingFinancialYearsProvider);

    return Material(
      color: context.surface.defaultSurface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: fyAsync.when(
          loading: () => const ShimmerWrap(
            child: ShimmerBox(height: 48, borderRadius: 12),
          ),
          error: (err, stack) => _noFinancialYearMessage(),
          data: (fys) {
            if (fys.isEmpty) {
              return _noFinancialYearMessage();
            }
            return _financialYearBillingCyclePickers(
              filter,
              fys,
              border,
              hidesCycleDropdown: hidesCycleDropdown,
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoRecordsFullPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: DesignColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No records available',
              style: DesignTypography.headingM.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Financial year has not been created yet. Records will appear here once your society admin sets up billing.',
              textAlign: TextAlign.center,
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noFinancialYearMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: context.surface.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.surface.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.text.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No records available. Financial year has not been created yet.',
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialYearBillingCyclePickers(
    MaintenanceDashboardFilter filter,
    List<Map<String, dynamic>> financialYears,
    OutlineInputBorder border, {
    bool hidesCycleDropdown = false,
  }) {
    final fyId = filter.financialYearId;
    final cyclesAsync = fyId != null && fyId.isNotEmpty
        ? ref.watch(billingCyclesForFinancialYearProvider(fyId))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('maint-fy-${filter.financialYearId}'),
          initialValue: filter.financialYearId != null &&
                  financialYears.any(
                    (fy) => fy['id']?.toString() == filter.financialYearId,
                  )
              ? filter.financialYearId
              : null,
          style: DesignTypography.bodyMedium.copyWith(
            color: context.text.primary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.surface.elevated,
            labelText: 'Financial year',
            labelStyle: DesignTypography.labelSmall.copyWith(
              color: context.text.secondary,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: DesignColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          dropdownColor: context.surface.defaultSurface,
          items: financialYears
              .map(
                (fy) => DropdownMenuItem(
                  value: fy['id']?.toString(),
                  child: Text(fy['label']?.toString() ?? 'Year'),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final cur = ref.read(maintenanceDashboardFilterProvider);
            ref.read(maintenanceDashboardFilterProvider.notifier).state =
                cur.copyWith(
              financialYearId: id,
              clearBillingCycleId: true,
              clearCollectionCycleId: true,
            );
            ref.invalidate(billingCyclesForFinancialYearProvider(id));
            ref.invalidate(maintenanceDashboardProvider);
          },
        ),
        if (!hidesCycleDropdown) ...[
          const SizedBox(height: 10),
          if (cyclesAsync == null)
            Text(
              'Choose a financial year to load billing months.',
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
                fontSize: 11,
              ),
            )
          else
            cyclesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                userFacingMessage(e, 'Could not load billing cycles'),
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.error,
                  fontSize: 11,
                ),
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
                  return Text(
                    'No billing cycles exist for this financial year yet.',
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.secondary,
                      fontSize: 11,
                    ),
                  );
                }
                final selectedId =
                    filter.billingCycleId != null &&
                            cycles.any(
                              (c) => c['id']?.toString() == filter.billingCycleId,
                            )
                        ? filter.billingCycleId
                        : null;
                return _cycleChipStrip(cycles, fyId, selectedId);
              },
            ),
        ],
      ],
    );
  }

  /// Horizontal, tappable month chips for the financial year's billing cycles
  /// — replaces the old cycle dropdown for faster, more scannable switching.
  Widget _cycleChipStrip(
    List<Map<String, dynamic>> cycles,
    String? fyId,
    String? selectedId,
  ) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in cycles) ...[
              _cycleChip(c, fyId, selectedId),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cycleChip(
    Map<String, dynamic> c,
    String? fyId,
    String? selectedId,
  ) {
    final id = c['id']?.toString();
    final key = c['cycleKey']?.toString() ?? '';
    final my = monthYearFromCycleKey(key);
    final label = my != null
        ? DateFormat("MMM ''yy").format(DateTime(my.year, my.month))
        : key;
    final selected = id != null && id == selectedId;
    final isOpen = (c['status']?.toString() ?? '').toUpperCase() == 'OPEN';

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: DesignTypography.labelSmall.copyWith(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : context.text.secondary,
      ),
      backgroundColor: context.surface.elevated,
      selectedColor: DesignColors.primary,
      side: BorderSide(
        color: selected ? DesignColors.primary : context.surface.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      avatar: (isOpen && !selected)
          ? Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: DesignColors.success,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onSelected: (_) {
        if (id == null || my == null) return;
        _selectCycle(id, fyId, my.month, my.year);
      },
    );
  }

  void _selectCycle(String id, String? fyId, int month, int year) {
    final cur = ref.read(maintenanceDashboardFilterProvider);
    ref.read(maintenanceDashboardFilterProvider.notifier).state = cur.copyWith(
      billingCycleId: id,
      month: month,
      year: year,
      clearBillingCycleId: false,
      clearFinancialYearId: false,
      financialYearId: fyId,
      clearCollectionCycleId: true,
    );
    ref.invalidate(maintenanceDashboardProvider);
  }

  /// Hand off to the vetted dues/pay flow (which computes the authoritative
  /// amount) and refresh balances on return.
  void _goToDues() {
    context.push('/resident/maintenance/dues').then((_) {
      if (!mounted) return;
      ref.invalidate(maintenanceDashboardProvider);
      ref.invalidate(pendingMaintenanceProvider);
      ref.invalidate(outstandingDuesProvider);
    });
  }

  /// Error + retry state for the FY-scoped tabs (Year review, Shortfall) when a
  /// `yearlyBreakdownForYearProvider` fetch fails. Wrapped in a scrollable so
  /// pull-to-refresh works; Retry re-runs every year breakdown.
  Widget _yearDataErrorState(Object error) {
    return _wrapTabWithRefresh(
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 360,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: DesignColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load cycle data',
                      style: DesignTypography.headingM
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userFacingMessage(error, 'Could not load year breakdown.'),
                      textAlign: TextAlign.center,
                      style: DesignTypography.bodySmall
                          .copyWith(color: context.text.secondary),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(yearlyBreakdownForYearProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
