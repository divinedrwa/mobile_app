import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants/app_constants.dart';

/// Local storage service.
///
/// User-data, role, society and similar non-secret keys live in
/// [SharedPreferences] (fast, synchronous reads after [init]). The auth
/// token lives in [FlutterSecureStorage] (Keychain on iOS, encrypted
/// SharedPreferences on Android) so that a backed-up or rooted device
/// cannot trivially extract it.
class StorageService {
  static SharedPreferences? _prefs;

  /// Token storage uses the same options as [SecureCredentialsStore] so the
  /// behavior on locked / first-unlock screens matches across the app.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first');
    }
    return _prefs!;
  }

  // Token management — secure storage only. Existing devices that upgraded
  // from a build that wrote the JWT to plain prefs will hit the legacy
  // migration path inside [getToken] exactly once and then live in secure
  // storage from then on.
  static Future<void> saveToken(String token) async {
    await _secure.write(key: AppConstants.keyToken, value: token);
    // Defensive: a previous build may have left a plaintext copy here.
    await prefs.remove(AppConstants.keyToken);
  }

  static Future<String?> getToken() async {
    final secure = await _secure.read(key: AppConstants.keyToken);
    if (secure != null && secure.isNotEmpty) return secure;
    // One-shot migration: copy any plaintext token from older builds into
    // secure storage, then wipe the plaintext so it doesn't linger in
    // backups or on rooted devices.
    final legacy = prefs.getString(AppConstants.keyToken);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: AppConstants.keyToken, value: legacy);
      await prefs.remove(AppConstants.keyToken);
      return legacy;
    }
    return null;
  }

  static Future<void> removeToken() async {
    await _secure.delete(key: AppConstants.keyToken);
    await prefs.remove(AppConstants.keyToken);
  }

  // Refresh token — always secure storage.
  static Future<void> saveRefreshToken(String token) async {
    await _secure.write(key: AppConstants.keyRefreshToken, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return _secure.read(key: AppConstants.keyRefreshToken);
  }

  static Future<void> removeRefreshToken() async {
    await _secure.delete(key: AppConstants.keyRefreshToken);
  }

  /// Fills [userData] 'societyId' when the API omits it, using preferred login and the
  /// last stored key. Call before persisting or when building [UserModel] from cache.
  static void ensureSocietyIdInUserMap(Map<String, dynamic> userData) {
    final v = userData['societyId']?.toString().trim() ?? '';
    if (v.isNotEmpty) return;
    final pref = getPreferredLoginSocietyId()?.trim();
    if (pref != null && pref.isNotEmpty) {
      userData['societyId'] = pref;
      return;
    }
    final stored = getSocietyId()?.trim();
    if (stored != null && stored.isNotEmpty) {
      userData['societyId'] = stored;
    }
  }

  // User data management
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    ensureSocietyIdInUserMap(userData);
    await prefs.setString(AppConstants.keyUserData, json.encode(userData));
    await prefs.setString(AppConstants.keyUserId, userData['id']?.toString() ?? '');
    await prefs.setString(AppConstants.keyUserRole, userData['role']?.toString() ?? '');

    if (userData['societyId'] != null &&
        userData['societyId'].toString().trim().isNotEmpty) {
      await prefs.setString(
        AppConstants.keySocietyId,
        userData['societyId'].toString(),
      );
    }

    if (userData['villaId'] != null) {
      await prefs.setString(AppConstants.keyVillaId, userData['villaId'].toString());
    }
  }

  static Map<String, dynamic>? getUserData() {
    final userData = prefs.getString(AppConstants.keyUserData);
    if (userData != null) {
      return json.decode(userData);
    }
    return null;
  }

  static String? getUserId() {
    return prefs.getString(AppConstants.keyUserId);
  }

  static String? getUserRole() {
    return prefs.getString(AppConstants.keyUserRole);
  }

  static String? getSocietyId() {
    return prefs.getString(AppConstants.keySocietyId);
  }

  static String? getVillaId() {
    return prefs.getString(AppConstants.keyVillaId);
  }

  static Future<void> savePreferredLoginSocietyId(String id) async {
    final t = id.trim();
    if (t.isEmpty) return;
    await prefs.setString(AppConstants.keyPreferredLoginSocietyId, t);
  }

  static String? getPreferredLoginSocietyId() {
    return prefs.getString(AppConstants.keyPreferredLoginSocietyId);
  }

  /// Persists society chosen on the selection screen (id + label for login UI).
  static Future<void> savePreferredLoginSociety({
    required String id,
    required String name,
  }) async {
    final sid = id.trim();
    if (sid.isEmpty) return;
    await prefs.setString(AppConstants.keyPreferredLoginSocietyId, sid);
    final label = name.trim();
    if (label.isNotEmpty) {
      await prefs.setString(AppConstants.keyPreferredLoginSocietyName, label);
    }
  }

  static String? getPreferredLoginSocietyName() {
    return prefs.getString(AppConstants.keyPreferredLoginSocietyName);
  }

  /// Clears JWT + cached user rows only (keeps API URL, biometric prefs, preferred society for login).
  static Future<void> clearAuthUserSession() async {
    await removeToken();
    await removeRefreshToken();
    await prefs.remove(AppConstants.keyUserData);
    await prefs.remove(AppConstants.keyUserId);
    await prefs.remove(AppConstants.keyUserRole);
    await prefs.remove(AppConstants.keyVillaId);
    await prefs.remove(AppConstants.keySocietyId);
  }

  // Clear all data (logout). Preserves device-level settings (API base URL,
  // biometric/notification toggles) and the preferred login society so the
  // user lands on the login screen (not society-select) after logout or
  // password change. The stale X-Society-Id concern is mitigated by
  // DioClient.reset() which clears the interceptor cache during logout.
  static Future<void> clearAll() async {
    final apiBase = prefs.getString(AppConstants.keyApiBaseUrl);
    final biometricPref = prefs.getBool(AppConstants.keyBiometricLoginEnabled);
    final notificationsEnabled = prefs.getBool(AppConstants.keyNotificationsEnabled);
    final pushEnabled = prefs.getBool(AppConstants.keyPushNotificationsEnabled);
    final preferredSocietyId = prefs.getString(AppConstants.keyPreferredLoginSocietyId);
    final preferredSocietyName = prefs.getString(AppConstants.keyPreferredLoginSocietyName);
    final rememberMe = prefs.getBool(AppConstants.keyRememberMe);
    await prefs.clear();
    // The JWT and refresh token live in secure storage; prefs.clear() doesn't reach them.
    await _secure.delete(key: AppConstants.keyToken);
    await _secure.delete(key: AppConstants.keyRefreshToken);
    if (apiBase != null && apiBase.isNotEmpty) {
      await prefs.setString(AppConstants.keyApiBaseUrl, apiBase);
    }
    if (biometricPref != null) {
      await prefs.setBool(AppConstants.keyBiometricLoginEnabled, biometricPref);
    }
    if (notificationsEnabled != null) {
      await prefs.setBool(AppConstants.keyNotificationsEnabled, notificationsEnabled);
    }
    if (pushEnabled != null) {
      await prefs.setBool(AppConstants.keyPushNotificationsEnabled, pushEnabled);
    }
    if (preferredSocietyId != null && preferredSocietyId.isNotEmpty) {
      await prefs.setString(AppConstants.keyPreferredLoginSocietyId, preferredSocietyId);
    }
    if (preferredSocietyName != null && preferredSocietyName.isNotEmpty) {
      await prefs.setString(AppConstants.keyPreferredLoginSocietyName, preferredSocietyName);
    }
    if (rememberMe == true) {
      await prefs.setBool(AppConstants.keyRememberMe, true);
    }
  }

  // Generic methods
  static Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }

  static String? getString(String key) {
    return prefs.getString(key);
  }

  static Future<void> setBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return prefs.getBool(key);
  }

  static Future<void> setInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return prefs.getInt(key);
  }

  static Future<void> remove(String key) async {
    await prefs.remove(key);
  }
}
