import 'package:intl/intl.dart';

/// Admin banner/poll forms store calendar days as UTC instants (midnight or
/// end-of-day). Format using the UTC calendar date so IST does not show 5:30 AM.
String formatCommunityCalendarDate(DateTime dt) {
  final d = dt.toUtc();
  return DateFormat('MMM d, y').format(DateTime(d.year, d.month, d.day));
}

String formatCommunityCalendarDateLong(DateTime dt) {
  final d = dt.toUtc();
  return DateFormat('dd MMM yyyy').format(DateTime(d.year, d.month, d.day));
}

/// Real timestamps (notice posted, document uploaded) — local date + time.
String formatCommunityTimestamp(DateTime dt) {
  return DateFormat('MMM d, y • h:mm a').format(dt.toLocal());
}
