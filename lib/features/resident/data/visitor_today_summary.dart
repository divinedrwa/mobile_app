import 'models/visitor_model.dart';
import 'providers/visitor_history_provider.dart';

bool visitorIsCheckedOut(VisitorModel visitor) {
  if (visitor.checkOutTime != null) return true;
  return visitor.status.toUpperCase() == 'CHECKED_OUT';
}

/// On premises now — walk-in, pre-approved, OTP/QR, delivery, cab, etc.
bool visitorIsInside(VisitorModel visitor) {
  if (visitorIsCheckedOut(visitor)) return false;
  return visitor.status.toUpperCase() == 'CHECKED_IN';
}

DateTime? visitorCheckInLocal(VisitorModel visitor) {
  return visitor.checkInTime?.toLocal();
}

bool visitorCheckedInToday(VisitorModel visitor, {DateTime? now}) {
  final checkIn = visitorCheckInLocal(visitor);
  if (checkIn == null) return false;
  final at = (now ?? DateTime.now()).toLocal();
  final todayStart = DateTime(at.year, at.month, at.day);
  final tomorrow = todayStart.add(const Duration(days: 1));
  return !checkIn.isBefore(todayStart) && checkIn.isBefore(tomorrow);
}

/// Computes today's visitor counts for this resident (all entry types).
VisitorTodaySummary computeVisitorTodaySummary(
  Iterable<VisitorModel> visitors, {
  DateTime? now,
}) {
  final today = visitors.where((v) => visitorCheckedInToday(v, now: now)).toList();

  var inside = 0;
  var completed = 0;
  for (final v in today) {
    if (visitorIsInside(v)) {
      inside++;
    } else if (visitorIsCheckedOut(v)) {
      completed++;
    }
  }

  return (total: today.length, checkedIn: inside, checkedOut: completed);
}

/// API summary is authoritative; history is a fallback while loading.
VisitorTodaySummary? resolveVisitorTodaySummary({
  VisitorTodaySummary? apiSummary,
  List<VisitorModel>? history,
}) {
  if (apiSummary != null) return apiSummary;
  if (history != null) return computeVisitorTodaySummary(history);
  return null;
}
