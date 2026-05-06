/// Registered by [DivineApp] so Dio can force logout when the API reports a deactivated account.
typedef AccountDeactivatedCallback = Future<void> Function();

/// Runs [logout + navigate to login] when the server returns 403 "Account is deactivated".
class AccountDeactivatedHandler {
  AccountDeactivatedHandler._();

  static AccountDeactivatedCallback? _callback;
  static bool _running = false;

  static void register(AccountDeactivatedCallback callback) {
    _callback = callback;
  }

  /// Fire-and-forget from [ErrorInterceptor]; safe if multiple requests fail at once.
  static Future<void> triggerIfRegistered() async {
    final cb = _callback;
    if (cb == null || _running) return;
    _running = true;
    try {
      await cb();
    } catch (_) {
      // Ignore — interceptor still surfaces the API error to the caller if needed.
    } finally {
      _running = false;
    }
  }
}
