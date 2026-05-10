import 'package:dio/dio.dart';
import '../../utils/storage_service.dart';

/// Adds [X-Society-Id] on every request when tenant context is known (logged-in user,
/// or society chosen on the login flow). Server JWT remains authoritative; header aids tracing.
///
/// The resolved society ID is cached in memory after the first lookup so
/// subsequent requests avoid repeated storage reads. Call [clearCache] on
/// logout or society switch.
class SocietyContextInterceptor extends Interceptor {
  static const _headerName = 'X-Society-Id';

  static String? _cachedSocietyId;

  /// Clears the in-memory society ID cache. Call on logout or society change.
  static void clearCache() {
    _cachedSocietyId = null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    String? sid = _cachedSocietyId;
    if (sid == null) {
      sid = _resolvedSocietyId();
      if (sid != null && sid.isNotEmpty) {
        _cachedSocietyId = sid;
      }
    }
    if (sid != null && sid.isNotEmpty) {
      options.headers[_headerName] = sid;
    }
    handler.next(options);
  }

  String? _resolvedSocietyId() {
    final u = StorageService.getSocietyId()?.trim();
    if (u != null && u.isNotEmpty) return u;
    return StorageService.getPreferredLoginSocietyId()?.trim();
  }
}
