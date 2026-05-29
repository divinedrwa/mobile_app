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

  // Check for well-known error codes in both 'message' and legacy 'error' fields.
  final message = data['message'];
  final error = data['error'];
  final code = message is String ? message : (error is String ? error : null);

  if (code == 'RATE_LIMIT_EXCEEDED') {
    final retryAfter = data['retryAfter']?.toString() ?? '60';
    return 'Too many requests. Please wait $retryAfter seconds and try again.';
  }

  if (code == 'DUPLICATE_PAYMENT') {
    return 'This payment has already been recorded.';
  }

  if (code == 'INVALID_AMOUNT') {
    final msg = data['message'];
    return msg is String ? msg : 'Payment amount must be positive';
  }

  // Zod validation issues array
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

  // Prefer 'message' (backend standard), fall back to 'error' (legacy)
  if (message is String && message.trim().isNotEmpty) {
    return message.trim();
  }
  if (error is String && error.trim().isNotEmpty) {
    return error.trim();
  }
  return fallback;
}
