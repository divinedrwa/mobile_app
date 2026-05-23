/// Registered by [DivineApp] so Dio can force logout when the API returns
/// a generic 401 (token expired, revoked, server-side rotated secret, etc.).
typedef SessionExpiredCallback = Future<void> Function();

/// Fires **exactly once** until explicitly reset. Without this guard,
/// N parallel/queued requests that all 401 would each kick off a logout +
/// redirect, resulting in N login screens and a broken nav stack.
///
/// The flag is intentionally **sticky** — once triggered it stays latched
/// until [reset] is called (typically after a successful login re-registers
/// the callback). This prevents the old Dio interceptor chain from
/// re-triggering logout while the app is restarting.
class SessionExpiredHandler {
  SessionExpiredHandler._();

  static SessionExpiredCallback? _callback;
  static bool _triggered = false;

  static void register(SessionExpiredCallback callback) {
    _callback = callback;
    // A fresh registration (after login / app restart) clears the latch.
    _triggered = false;
  }

  /// Fire-and-forget from [ErrorInterceptor]; safe to call concurrently.
  /// The interceptor still rejects the originating request so callers can
  /// surface a contextual error if they want, but the user is being sent
  /// to the login screen regardless.
  static Future<void> triggerIfRegistered() async {
    final cb = _callback;
    if (cb == null || _triggered) return;
    _triggered = true;
    try {
      await cb();
    } catch (_) {
      // Local session must clear even if the server-side logout fails.
    }
    // Intentionally NO reset — stays latched until register() is called
    // again after a successful login.
  }
}
