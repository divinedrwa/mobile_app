/// Parses backend error JSON (Express + Zod) into a user-visible string.
String parseApiErrorMessage(dynamic data, [String fallback = 'Something went wrong']) {
  if (data is String) {
    final s = data.trim();
    if (s.length > 200 && (s.startsWith('<') || s.contains('<!DOCTYPE'))) {
      return 'Server returned a web page instead of JSON. Check API base URL (Settings → API server).';
    }
    if (s.isNotEmpty) return s;
    return fallback;
  }
  if (data is! Map) return fallback;

  final issues = data['issues'];
  if (issues is List && issues.isNotEmpty) {
    final parts = <String>[];
    for (final issue in issues) {
      if (issue is Map) {
        final pathList = issue['path'];
        final pathStr = pathList is List
            ? pathList.map((x) => x.toString()).join('.')
            : '';
        final m = issue['message'] as String? ?? '';
        parts.add(pathStr.isEmpty ? m : '$pathStr: $m');
      }
    }
    if (parts.isNotEmpty) {
      return parts.join('\n');
    }
  }

  final msg = data['message'];
  if (msg is String && msg.trim().isNotEmpty) {
    return msg.trim();
  }
  final err = data['error'];
  if (err is String && err.trim().isNotEmpty) {
    return err.trim();
  }
  return fallback;
}
