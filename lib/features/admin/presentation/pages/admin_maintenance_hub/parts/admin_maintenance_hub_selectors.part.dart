part of '../admin_maintenance_hub_screen.dart';

extension _AdminMaintenanceHubSelectorsPart on _AdminMaintenanceHubScreenState {
  // ── FY + cycle selector ───────────────────────────────────────────

  Widget _fyAndCycleSelector(AdminMaintenanceFilter filter) {
    final fysAsync = ref.watch(adminCollectionFinancialYearsProvider);

    return fysAsync.when(
      loading: () => ShimmerWrap(
        child: ShimmerBox(height: 48, borderRadius: DesignRadius.lg),
      ),
      error: (_, _) => EnterpriseInfoBanner(
        icon: Icons.error_outline,
        title: 'Load failed',
        message: 'Couldn\'t load financial years',
        tone: EnterpriseTone.danger,
      ),
      data: (fys) {
        if (fys.isEmpty) {
          return EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'No data',
            message: 'No financial years configured',
            tone: EnterpriseTone.info,
          );
        }

        return Column(
          children: [
            _fyDropdown(fys, filter),
            const SizedBox(height: AppSpacing.sm),
            _cycleChips(filter),
          ],
        );
      },
    );
  }

  Widget _fyDropdown(
    List<Map<String, dynamic>> fys,
    AdminMaintenanceFilter filter,
  ) {
    return EnterprisePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButton<String>(
        value: filter.financialYearId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.keyboard_arrow_down,
            color: DesignColors.textSecondary),
        style: DesignTypography.bodyMedium.copyWith(
          color: DesignColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        items: fys
            .map((fy) => DropdownMenuItem<String>(
                  value: fy['id']?.toString(),
                  child: Text(fy['label']?.toString() ?? 'Untitled'),
                ))
            .toList(),
        onChanged: (id) {
          if (id == null) return;
          final cur = ref.read(adminMaintenanceFilterProvider);
          ref.read(adminMaintenanceFilterProvider.notifier).state =
              cur.copyWith(
            financialYearId: id,
            clearCollectionCycleId: true,
            clearBillingCycleId: true,
          );
          _selectionInitialised = false;
        },
      ),
    );
  }

  Widget _cycleChips(AdminMaintenanceFilter filter) {
    final fyId = filter.financialYearId;
    if (fyId == null || fyId.isEmpty) {
      return const SizedBox.shrink();
    }

    final cyclesAsync = ref.watch(adminCollectionCyclesForFYProvider(fyId));

    return cyclesAsync.when(
      loading: () => ShimmerWrap(
        child: SizedBox(
          height: 44,
          child: Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShimmerBox(height: 36, width: 56, borderRadius: DesignRadius.full),
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => EnterpriseInfoBanner(
        icon: Icons.error_outline,
        title: 'Load failed',
        message: 'Couldn\'t load billing periods',
        tone: EnterpriseTone.danger,
      ),
      data: (cycles) {
        if (cycles.isEmpty) {
          return EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'No data',
            message: 'No billing periods for this year',
            tone: EnterpriseTone.info,
          );
        }

        final selectedCycleId = filter.maintenanceCollectionCycleId;

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cycles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cycle = cycles[index];
              final cycleId = cycle['id']?.toString();
              final isSelected = cycleId == selectedCycleId;

              final pm = (cycle['periodMonth'] as num?)?.toInt();
              final py = (cycle['periodYear'] as num?)?.toInt();
              final chipLabel = pm != null
                  ? DateFormat('MMM').format(DateTime(py ?? 2000, pm))
                  : (cycle['title']?.toString() ?? '?');

              return ChoiceChip(
                label: Text(chipLabel),
                selected: isSelected,
                selectedColor: DesignColors.primary,
                backgroundColor: DesignColors.surface,
                side: BorderSide(
                  color: isSelected
                      ? DesignColors.primary
                      : DesignColors.borderLight,
                ),
                labelStyle: DesignTypography.bodySmall.copyWith(
                  color:
                      isSelected ? Colors.white : DesignColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) {
                  final cur = ref.read(adminMaintenanceFilterProvider);
                  ref
                      .read(adminMaintenanceFilterProvider.notifier)
                      .state = cur.copyWith(
                    maintenanceCollectionCycleId: cycleId,
                    month: pm ?? cur.month,
                    year: py ?? cur.year,
                    clearBillingCycleId: true,
                  );
                  _selectionInitialised = false;
                },
              );
            },
          ),
        );
      },
    );
  }
}
