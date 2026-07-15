part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardLifecyclePart on _MaintenancePaymentScreenState {
  Future<void> _applyDeepLinkBillingCycleOnly(
    String billingCycleId,
    String? collectionCycleId,
  ) async {
    if (!mounted) return;
    try {
      final ctx = await ref
          .read(maintenanceRepositoryProvider)
          .getBillingCycleContext(billingCycleId);
      if (!mounted || ctx == null) return;
      final fyMap = ctx['financialYear'];
      final bcMap = ctx['billingCycle'];
      if (fyMap is! Map || bcMap is! Map) return;
      final fyId = fyMap['id']?.toString();
      final key = bcMap['cycleKey']?.toString() ?? '';
      final my = monthYearFromCycleKey(key);
      if (fyId == null || fyId.isEmpty || my == null) return;

      final cur = ref.read(maintenanceDashboardFilterProvider);
      ref.read(maintenanceDashboardFilterProvider.notifier).state =
          cur.copyWith(
        month: my.month,
        year: my.year,
        maintenanceCollectionCycleId: collectionCycleId,
        clearCollectionCycleId: collectionCycleId == null,
        financialYearId: fyId,
        clearFinancialYearId: false,
        billingCycleId: billingCycleId,
        clearBillingCycleId: false,
      );
      ref.invalidate(maintenanceDashboardProvider);
      ref.invalidate(billingCyclesForFinancialYearProvider(fyId));
    } catch (_) {}
  }

  Future<void> _pullRefreshMaintenance() async {
    ref.invalidate(maintenanceDashboardProvider);
    ref.invalidate(pendingMaintenanceProvider);
    ref.invalidate(maintenanceHistoryProvider);
    ref.invalidate(billingFinancialYearsProvider);
    ref.invalidate(outstandingDuesProvider);
    ref.invalidate(yearlyBreakdownForYearProvider);
    final fy = ref.read(maintenanceDashboardFilterProvider).financialYearId;
    if (fy != null && fy.isNotEmpty) {
      ref.invalidate(billingCyclesForFinancialYearProvider(fy));
    }
    ref.invalidate(residentBillingCycleProvider);
    try {
      await ref.read(maintenanceDashboardProvider.future);
    } catch (_) {}
    try {
      await ref.read(pendingMaintenanceProvider.future);
    } catch (_) {}
    try {
      await ref.read(maintenanceHistoryProvider.future);
    } catch (_) {}
  }

  void _ensureBillingCycleMatchesFilter(
    String fyId,
    List<Map<String, dynamic>> cycles,
  ) {
    if (cycles.isEmpty) return;
    final cur = ref.read(maintenanceDashboardFilterProvider);
    if (cur.financialYearId != fyId) return;

    final byId = <String, Map<String, dynamic>>{
      for (final c in cycles)
        if (c['id'] != null) c['id'].toString(): c,
    };

    final Map<String, dynamic> chosen;
    final sel = cur.billingCycleId;
    if (sel != null && byId.containsKey(sel)) {
      chosen = byId[sel]!;
    } else {
      final def = pickDefaultBillingCycleId(cycles);
      if (def != null && byId.containsKey(def)) {
        chosen = byId[def]!;
      } else {
        chosen = cycles.last;
      }
    }

    final key = chosen['cycleKey']?.toString() ?? '';
    final my = monthYearFromCycleKey(key);
    if (my == null) return;

    final idStr = chosen['id']?.toString();
    if (cur.billingCycleId == idStr &&
        cur.month == my.month &&
        cur.year == my.year) {
      return;
    }

    ref.read(maintenanceDashboardFilterProvider.notifier).state =
        cur.copyWith(
          billingCycleId: idStr,
          month: my.month,
          year: my.year,
          clearBillingCycleId: false,
          clearFinancialYearId: false,
          financialYearId: fyId,
          clearCollectionCycleId: true,
        );
    ref.invalidate(maintenanceDashboardProvider);
  }
}
