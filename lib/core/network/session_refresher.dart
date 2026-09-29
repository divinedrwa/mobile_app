import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../utils/storage_service.dart';
import 'dio_client.dart';
import 'interceptors/auth_interceptor.dart';

enum SessionRefreshStatus {
  /// New tokens are stored (by this call or by a refresh that won a race).
  success,

  /// The server rejected the refresh token and no newer one exists: the
  /// session is really over.
  rejected,

  /// Network / timeout / 5xx / malformed response. The session may still be
  /// valid, so callers must keep the user logged in.
  transient,
}

class SessionRefreshResult {
  const SessionRefreshResult(this.status, [this.data]);

  final SessionRefreshStatus status;

  /// Response body of a successful refresh made by this process (may be null
  /// when another refresh stored the tokens first).
  final Map<String, dynamic>? data;
}

/// The single place that calls `/auth/refresh`.
///
/// The server rotates refresh tokens: using one revokes it. Two refreshes
/// with the same token (app start + a 401 from any request) used to make the
/// slower one fail and log the user out. All callers share one in-flight
/// refresh, and a rejection is ignored when a newer token was stored meanwhile.
class SessionRefresher {
  SessionRefresher._();

  static Future<SessionRefreshResult>? _inFlight;

  static Future<SessionRefreshResult> refresh() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  static Future<SessionRefreshResult> _run() async {
    final sent = await StorageService.getRefreshToken();
    if (sent == null || sent.isEmpty) {
      return const SessionRefreshResult(SessionRefreshStatus.rejected);
    }

    final parent = DioClient.dio.options;
    final dio = Dio(BaseOptions(
      baseUrl: parent.baseUrl,
      connectTimeout: parent.connectTimeout,
      receiveTimeout: parent.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    try {
      final response = await dio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': sent},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const SessionRefreshResult(SessionRefreshStatus.transient);
      }
      final token = data['token'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (token == null || token.isEmpty || refreshToken == null || refreshToken.isEmpty) {
        return const SessionRefreshResult(SessionRefreshStatus.transient);
      }
      await StorageService.saveToken(token);
      await StorageService.saveRefreshToken(refreshToken);
      AuthInterceptor.clearCache();
      return SessionRefreshResult(SessionRefreshStatus.success, data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return _rejectedUnlessRotatedMeanwhile(sent);
      }
      return const SessionRefreshResult(SessionRefreshStatus.transient);
    } catch (_) {
      return const SessionRefreshResult(SessionRefreshStatus.transient);
    }
  }

  static Future<SessionRefreshResult> _rejectedUnlessRotatedMeanwhile(String sent) async {
    final current = await StorageService.getRefreshToken();
    if (current != null && current.isNotEmpty && current != sent) {
      AuthInterceptor.clearCache();
      return const SessionRefreshResult(SessionRefreshStatus.success);
    }
    return const SessionRefreshResult(SessionRefreshStatus.rejected);
  }
}
