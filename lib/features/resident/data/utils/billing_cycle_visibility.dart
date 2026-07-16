/// Shared rules for which billing cycles appear in resident/maintenance UI.
bool isAppVisibleBillingCycle(Map<String, dynamic> cycle) {
  if (cycle['publishedAt'] == null) return false;
  final status = cycle['status']?.toString().toUpperCase() ?? '';
  return status == 'OPEN' || status == 'CLOSED';
}

({int month, int year})? billingCycleMonthYear(Map<String, dynamic> cycle) {
  var month = (cycle['month'] as num?)?.toInt() ?? 0;
  var year = (cycle['year'] as num?)?.toInt() ?? 0;
  if (month < 1 || year < 1) {
    final key = cycle['cycleKey']?.toString() ?? '';
    final parts = key.split('-');
    if (parts.length >= 2) {
      year = int.tryParse(parts[0]) ?? year;
      month = int.tryParse(parts[1]) ?? month;
    }
  }
  if (month < 1) month = (cycle['periodMonth'] as num?)?.toInt() ?? month;
  if (year < 1) year = (cycle['periodYear'] as num?)?.toInt() ?? year;
  if (month < 1 || month > 12 || year < 2000) return null;
  return (month: month, year: year);
}

List<Map<String, dynamic>> parseVisibleBillingCycles(Map<String, dynamic> body) {
  final raw = body['cycles'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where(isAppVisibleBillingCycle)
      .toList();
}

/// Prefer OPEN, then latest CLOSED — never draft/UPCOMING.
String? pickDefaultBillingCycleId(List<Map<String, dynamic>> cycles) {
  final visible = cycles.where(isAppVisibleBillingCycle).toList();
  if (visible.isEmpty) return null;

  for (final c in visible.reversed) {
    if (c['status']?.toString().toUpperCase() == 'OPEN') {
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
