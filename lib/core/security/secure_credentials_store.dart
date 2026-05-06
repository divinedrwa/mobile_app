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

  Future<void> saveCredentials({
    required String username,
    required String password,
    required String societyId,
  }) async {
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kSocietyId, value: societyId.trim());
  }

  Future<({String username, String password, String societyId})?> readCredentials() async {
    final u = await _storage.read(key: _kUsername);
    final p = await _storage.read(key: _kPassword);
    final s = await _storage.read(key: _kSocietyId);
    if (u == null || u.isEmpty || p == null || s == null || s.isEmpty) return null;
    return (username: u, password: p, societyId: s.trim());
  }

  Future<bool> hasCredentials() async {
    final u = await _storage.read(key: _kUsername);
    final s = await _storage.read(key: _kSocietyId);
    return u != null && u.isNotEmpty && s != null && s.isNotEmpty;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kSocietyId);
  }
}
