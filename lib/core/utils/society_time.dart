import 'package:intl/intl.dart';

/// Society default timezone: Asia/Kolkata (IST, UTC+5:30, no DST).
const Duration kIstOffset = Duration(hours: 5, minutes: 30);

/// Wall-clock parts in IST for a UTC (or local) instant.
DateTime _toIstParts(DateTime instant) {
  final utc = instant.toUtc();
  final ist = utc.add(kIstOffset);
  return DateTime(ist.year, ist.month, ist.day, ist.hour, ist.minute, ist.second, ist.millisecond);
}

/// YYYY-MM-DD in society local time.
String societyLocalDateKey(DateTime instant) {
  final p = _toIstParts(instant);
  return DateFormat('yyyy-MM-dd').format(DateTime(p.year, p.month, p.day));
}

/// Whether [instant] falls on today's society-local calendar day.
bool isSocietyLocalToday(DateTime instant) {
  return societyLocalDateKey(instant) == societyLocalDateKey(DateTime.now().toUtc());
}

/// Start of society-local calendar day containing [instant] (as UTC DateTime).
DateTime startOfSocietyLocalDay(DateTime instant) {
  final key = societyLocalDateKey(instant);
  final parts = key.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]).subtract(kIstOffset);
}

/// Compare calendar days in IST: negative if a before b, 0 if same day, positive if after.
int compareSocietyLocalDays(DateTime a, DateTime b) {
  return societyLocalDateKey(a).compareTo(societyLocalDateKey(b));
}

/// Whole calendar days from [from] to [to] in IST (positive when to is later).
int societyLocalDayDifference(DateTime from, DateTime to) {
  final fromStart = startOfSocietyLocalDay(from);
  final toStart = startOfSocietyLocalDay(to);
  return toStart.difference(fromStart).inDays;
}
