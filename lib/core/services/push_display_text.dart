import '../constants/app_constants.dart';

/// Code point ranges that are invisible on screen but are not removed by `trim()`: control characters,
/// no-break space, soft hyphen, zero-width and direction marks, line and paragraph separators, invisible
/// operators and the byte-order mark. Numbers, so this file holds no invisible characters itself.
const List<List<int>> _invisibleRanges = [
  [0x00, 0x08], [0x0B, 0x0C], [0x0E, 0x1F], [0x7F, 0x7F], [0xA0, 0xA0], [0xAD, 0xAD],
  [0x200B, 0x200F], [0x2028, 0x202E], [0x2060, 0x2064], [0xFEFF, 0xFEFF],
];

bool _isInvisible(int c) {
  for (final r in _invisibleRanges) {
    if (c >= r[0] && c <= r[1]) return true;
  }
  return false;
}

/// Invisible characters and every kind of whitespace (tab, newline, ideographic space, ...).
bool _isSeparator(int c) =>
    _isInvisible(c) ||
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0x85 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000;

/// The visible text of [value] ('' when there is none): invisible characters removed, runs of
/// whitespace collapsed to one space, leading and trailing whitespace dropped.
String cleanPushText(String? value) {
  if (value == null || value.isEmpty) return '';
  final out = StringBuffer();
  var pendingSpace = false;
  for (final c in value.runes) {
    if (_isSeparator(c)) {
      pendingSpace = out.isNotEmpty;
      continue;
    }
    if (pendingSpace) {
      out.write(' ');
      pendingSpace = false;
    }
    out.write(String.fromCharCode(c));
  }
  return out.toString();
}

/// The words to show for a push, or `null` when it carries none.
///
/// A push with no title and no body used to be shown as a notification headed "Notification" with
/// the body "Notification". Showing nothing is better than showing that. Text comes from the
/// message's own notification first, then from the same text the server repeats in the data block.
/// Mirrors the server's rule (`backend/src/lib/pushText.ts`):
///   - title and body present: used as given;
///   - title only: the body repeats the title;
///   - body only: the title is the app name;
///   - neither: `null`.
({String title, String body})? resolvePushDisplayText({
  String? notificationTitle,
  String? notificationBody,
  String? dataTitle,
  String? dataBody,
}) {
  final nTitle = cleanPushText(notificationTitle);
  final nBody = cleanPushText(notificationBody);
  var title = nTitle.isNotEmpty ? nTitle : cleanPushText(dataTitle);
  var body = nBody.isNotEmpty ? nBody : cleanPushText(dataBody);
  if (title.isEmpty && body.isEmpty) return null;
  if (title.isEmpty) title = AppConstants.appName;
  if (body.isEmpty) body = title;
  return (title: title, body: body);
}
