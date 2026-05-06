import 'package:dio/dio.dart';
import '../../utils/storage_service.dart';

/// Adds [X-Society-Id] on every request when tenant context is known (logged-in user,
/// or society chosen on the login flow). Server JWT remains authoritative; header aids tracing.
class SocietyContextInterceptor extends Interceptor {
  static const _headerName = 'X-Society-Id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sid = _resolvedSocietyId();
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
