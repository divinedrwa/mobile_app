import '../../../../data/providers/maintenance_provider.dart';
export '../../../../data/utils/billing_cycle_visibility.dart'
    show pickDefaultBillingCycleId, pickDefaultFinancialYearId;

/// Some gateways or proxies wrap JSON as `{ "data": { ... } }` — normalize for the UI.
Map<String, dynamic> normalizeDashboardPayload(Map<String, dynamic> raw) {
  final nested = raw['data'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return raw;
}

({int month, int year})? monthYearFromCycleKey(String cycleKey) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(cycleKey.trim());
  if (m == null) return null;
  final y = int.tryParse(m.group(1)!);
  final mo = int.tryParse(m.group(2)!);
  if (y == null || mo == null || mo < 1 || mo > 12) return null;
  return (month: mo, year: y);
}

({int month, int year}) resolvedDashboardPeriod(
  Map<String, dynamic> root,
  MaintenanceDashboardFilter filter,
) {
  final raw = root['filter'];
  if (raw is Map) {
    final mo = (raw['month'] as num?)?.toInt();
    final yr = (raw['year'] as num?)?.toInt();
    if (mo != null && yr != null && mo >= 1 && mo <= 12) {
      return (month: mo, year: yr);
    }
  }
  return (month: filter.month, year: filter.year);
}
