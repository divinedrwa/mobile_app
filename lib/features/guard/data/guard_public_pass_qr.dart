/// Extracts the opaque token from a production public visitor-pass URL.
///
/// Only HTTPS `/visit/<token>` URLs are accepted. Arbitrary scanned URLs are
/// never forwarded to the API.
String? parseVisitorPublicPassToken(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 2 || segments.first != 'visit') return null;
  final token = segments.last;
  return RegExp(r'^[A-Za-z0-9_-]{40,64}$').hasMatch(token) ? token : null;
}

/// Converts the authenticated resolve response into the existing approval
/// route's supported query fields.
Map<String, String>? guardPayloadFromResolvedPublicPass(
  Map<String, dynamic> response,
) {
  if (response['verified'] != true || response['preApproved'] is! Map) {
    return null;
  }
  final pre = Map<String, dynamic>.from(response['preApproved'] as Map);
  final out = <String, String>{};

  void add(String key, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) out[key] = text;
  }

  add('otp', response['otp'] ?? pre['otp']);
  add('name', pre['name']);
  add('phone', pre['phone']);
  add('villaId', pre['villaId']);
  add('preApprovedId', pre['id']);
  return out['otp']?.isNotEmpty == true ? out : null;
}
