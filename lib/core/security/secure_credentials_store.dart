import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores username/password (+ society) for biometric login only (encrypted by the OS).
class SecureCredentialsStore {
  SecureCredentialsStore._();
  static final SecureCredentialsStore instance = SecureCredentialsStore._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kUsername = 'biometric_login_username';
  static const _kPassword = 'biometric_login_password';
  static const _kSocietyId = 'biometric_login_society_id';
  static const _kSavedAt = 'biometric_login_saved_at';

  /// Biometric credentials expire after this duration to prevent stale
  /// passwords persisting indefinitely after a password change on another device.
  static const _maxCredentialAge = Duration(days: 90);

  // "Remember me" credential keys (separate from biometric).
  static const _kRememberUsername = 'remember_me_username';
  static const _kRememberPassword = 'remember_me_password';

  /// Self-healing read. Encrypted storage becomes undecryptable after a
  /// reinstall with a different signing key / keystore reset
  /// (AEADBadTagException). Wipe the corrupt store and return null rather than
  /// throwing, so the login screen just falls back to manual entry.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  Future<void> saveCredentials({
    required String username,
    required String password,
    required String societyId,
  }) async {
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kSocietyId, value: societyId.trim());
    await _storage.write(key: _kSavedAt, value: DateTime.now().toIso8601String());
  }

  Future<({String username, String password, String societyId})?> readCredentials() async {
    final u = await _read(_kUsername);
    final p = await _read(_kPassword);
    final s = await _read(_kSocietyId);
    if (u == null || u.isEmpty || p == null || s == null || s.isEmpty) return null;

    // Auto-expire stale credentials.
    final savedAtStr = await _read(_kSavedAt);
    if (savedAtStr != null) {
      final savedAt = DateTime.tryParse(savedAtStr);
      if (savedAt != null && DateTime.now().difference(savedAt) > _maxCredentialAge) {
        await clearCredentials();
        return null;
      }
    }

    return (username: u, password: p, societyId: s.trim());
  }

  Future<bool> hasCredentials() async {
    final u = await _read(_kUsername);
    final s = await _read(_kSocietyId);
    return u != null && u.isNotEmpty && s != null && s.isNotEmpty;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kSocietyId);
    await _storage.delete(key: _kSavedAt);
  }

  /// Save username + password for "Remember me" (encrypted by OS).
  Future<void> saveRememberMe({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _kRememberUsername, value: username);
    await _storage.write(key: _kRememberPassword, value: password);
  }

  /// Read saved "Remember me" credentials; null if not stored.
  Future<({String username, String password})?> readRememberMe() async {
    final u = await _read(_kRememberUsername);
    final p = await _read(_kRememberPassword);
    if (u == null || u.isEmpty || p == null) return null;
    return (username: u, password: p);
  }

  /// Clear "Remember me" credentials.
  Future<void> clearRememberMe() async {
    await _storage.delete(key: _kRememberUsername);
    await _storage.delete(key: _kRememberPassword);
  }
}
