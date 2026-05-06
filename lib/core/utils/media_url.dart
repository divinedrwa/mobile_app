import '../constants/app_constants.dart';

/// Turns a server path like `/uploads/avatars/x.jpg` into a full URL using the
/// same host/port as [AppConstants.baseUrl] (API is under `/api`; files are not).
String? resolveServerFileUrl(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
  final t = pathOrUrl.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  final api = Uri.parse(AppConstants.baseUrl);
  final path = t.startsWith('/') ? t : '/$t';
  return Uri(
    scheme: api.scheme,
    host: api.host,
    port: api.hasPort ? api.port : null,
    path: path,
  ).toString();
}
