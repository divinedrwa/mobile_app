import '../../../../data/providers/maintenance_provider.dart';

/// Some gateways or proxies wrap JSON as `{ "data": { ... } }` — normalize for the UI.
Map<String, dynamic> normalizeDashboardPayload(Map<String, dynamic> raw) {
  final nested = raw['data'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return raw;
}

/// Pick a sensible default billing cycle among app-visible cycles.
String? pickDefaultBillingCycleId(List<Map<String, dynamic>> cycles) {
  final visible = cycles.where(isAppVisibleBillingCycle).toList();
  if (visible.isEmpty) return null;

  for (final c in visible.reversed) {
    if (c['status']?.toString().toUpperCase() == 'OPEN') {
      return c['id']?.toString();
    }
  }

  final now = DateTime.now();
  final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  for (final c in visible) {
    if (c['cycleKey']?.toString() == key) {
      return c['id']?.toString();
    }
  }

  return visible.last['id']?.toString();
}

String? pickDefaultFinancialYearId(List<Map<String, dynamic>> fys) {
  if (fys.isEmpty) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final fy in fys) {
    final s = DateTime.tryParse(fy['startDate']?.toString() ?? '');
    final e = DateTime.tryParse(fy['endDate']?.toString() ?? '');
    if (s == null || e == null) continue;
    final ds = DateTime(s.year, s.month, s.day);
    final de = DateTime(e.year, e.month, e.day);
    if (!today.isBefore(ds) && !today.isAfter(de)) {
      return fy['id']?.toString();
    }
  }
  return fys.first['id']?.toString();
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
