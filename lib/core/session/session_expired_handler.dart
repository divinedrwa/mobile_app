/// Registered by [DivineApp] so Dio can force logout when the API returns
/// a generic 401 (token expired, revoked, server-side rotated secret, etc.).
typedef SessionExpiredCallback = Future<void> Function();

/// Fires once per "burst" of failed requests. Without this guard, N parallel
/// requests that all 401 at once would each kick off a logout + redirect,
/// resulting in N login screens and a broken nav stack.
class SessionExpiredHandler {
  SessionExpiredHandler._();

  static SessionExpiredCallback? _callback;
  static bool _running = false;

  static void register(SessionExpiredCallback callback) {
    _callback = callback;
  }

  /// Fire-and-forget from [ErrorInterceptor]; safe to call concurrently.
  /// The interceptor still rejects the originating request so callers can
  /// surface a contextual error if they want, but the user is being sent
  /// to the login screen regardless.
  static Future<void> triggerIfRegistered() async {
    final cb = _callback;
    if (cb == null || _running) return;
    _running = true;
    try {
      await cb();
    } catch (_) {
      // Local session must clear even if the server-side logout fails.
    } finally {
      _running = false;
    }
  }
}
