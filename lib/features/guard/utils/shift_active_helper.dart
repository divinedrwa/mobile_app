/// Shared helper to determine whether a guard shift row is currently active.
///
/// Handles both absolute (one-off) shifts and recurring daily shifts,
/// including overnight windows where start > end (e.g. 22:00–06:00).
class ShiftActiveHelper {
  ShiftActiveHelper._();

  /// Returns `true` when at least one shift in [rows] covers [now].
  static bool hasActiveShift(
    List<Map<String, dynamic>> rows, [
    DateTime? now,
  ]) {
    final n = now ?? DateTime.now();
    for (final raw in rows) {
      if (_isActive(raw, n)) return true;
    }
    return false;
  }

  /// Returns `true` when the individual shift [raw] is active at [now].
  static bool isShiftActive(Map<String, dynamic> raw, [DateTime? now]) {
    return _isActive(raw, now ?? DateTime.now());
  }

  // ------------------------------------------------------------------

  static bool _isActive(Map<String, dynamic> raw, DateTime now) {
    final recurring = raw['recurringDaily'] == true;

    if (recurring) {
      return _isRecurringActive(raw, now);
    }
    return _isAbsoluteActive(raw, now);
  }

  /// Absolute (one-off) shift: [startTime, endTime] window.
  static bool _isAbsoluteActive(Map<String, dynamic> raw, DateTime now) {
    final start = _parseDateTime(raw['startTime']);
    final end = _parseDateTime(raw['endTime']);
    if (start == null || end == null) return false;
    return !now.isBefore(start) && !now.isAfter(end);
  }

  /// Recurring daily shift: compare minute-of-day.
  static bool _isRecurringActive(Map<String, dynamic> raw, DateTime now) {
    final sm = _toInt(raw['recurringStartMinutes']);
    final em = _toInt(raw['recurringEndMinutes']);
    if (sm == null || em == null) {
      // Fallback: derive from startTime/endTime
      return _isAbsoluteActive(raw, now);
    }
    final nm = now.hour * 60 + now.minute + now.second / 60;
    return _withinWindow(nm, sm.toDouble(), em.toDouble());
  }

  /// Half-open [start, end) with overnight wrap support.
  static bool _withinWindow(double now, double start, double end) {
    if (start == end) return false;
    if (start < end) return now >= start && now < end;
    // Overnight: e.g. 22:00-06:00
    return now >= start || now < end;
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return DateTime.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
