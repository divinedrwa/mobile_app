import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/push_sync_service.dart';
import '../../../shared/models/user_model.dart';

/// Map a single Unicode codepoint from mathematical/fullwidth ranges to ASCII.
int _mapConfusableRune(int rune) {
  // Mathematical Monospace (Xiaomi "font" keyboards)
  if (rune >= 0x1D670 && rune <= 0x1D689) return rune - 0x1D670 + 0x41; // A-Z
  if (rune >= 0x1D68A && rune <= 0x1D6A3) return rune - 0x1D68A + 0x61; // a-z
  if (rune >= 0x1D7F6 && rune <= 0x1D7FF) return rune - 0x1D7F6 + 0x30; // 0-9
  // Mathematical Bold
  if (rune >= 0x1D400 && rune <= 0x1D419) return rune - 0x1D400 + 0x41;
  if (rune >= 0x1D41A && rune <= 0x1D433) return rune - 0x1D41A + 0x61;
  if (rune >= 0x1D7CE && rune <= 0x1D7D7) return rune - 0x1D7CE + 0x30;
  // Mathematical Italic
  if (rune >= 0x1D434 && rune <= 0x1D44D) return rune - 0x1D434 + 0x41;
  if (rune >= 0x1D44E && rune <= 0x1D467) return rune - 0x1D44E + 0x61;
  // Mathematical Bold Italic
  if (rune >= 0x1D468 && rune <= 0x1D481) return rune - 0x1D468 + 0x41;
  if (rune >= 0x1D482 && rune <= 0x1D49B) return rune - 0x1D482 + 0x61;
  // Mathematical Sans-Serif
  if (rune >= 0x1D5A0 && rune <= 0x1D5B9) return rune - 0x1D5A0 + 0x41;
  if (rune >= 0x1D5BA && rune <= 0x1D5D3) return rune - 0x1D5BA + 0x61;
  if (rune >= 0x1D7E2 && rune <= 0x1D7EB) return rune - 0x1D7E2 + 0x30;
  // Mathematical Sans-Serif Bold
  if (rune >= 0x1D5D4 && rune <= 0x1D5ED) return rune - 0x1D5D4 + 0x41;
  if (rune >= 0x1D5EE && rune <= 0x1D607) return rune - 0x1D5EE + 0x61;
  if (rune >= 0x1D7EC && rune <= 0x1D7F5) return rune - 0x1D7EC + 0x30;
  // Fullwidth ASCII (CJK keyboards)
  if (rune >= 0xFF21 && rune <= 0xFF3A) return rune - 0xFF21 + 0x41;
  if (rune >= 0xFF41 && rune <= 0xFF5A) return rune - 0xFF41 + 0x61;
  if (rune >= 0xFF10 && rune <= 0xFF19) return rune - 0xFF10 + 0x30;
  return rune;
}

/// Normalize confusable Unicode and strip invisible characters.
String _sanitizeInput(String input) {
  final buf = StringBuffer();
  for (final rune in input.trim().runes) {
    buf.writeCharCode(_mapConfusableRune(rune));
  }
  return buf.toString().replaceAll(
    RegExp(r'[\u200B\u200C\u200D\uFEFF\u00AD\u2060]'),
    '',
  );
}

/// Outcome of a proactive token refresh attempt. Lets callers distinguish
/// "server rejected the refresh token" from "network was down".
enum RefreshResult { success, networkError, rejected }

/// Repository for authentication operations
class AuthRepository {
  Dio get _dio => DioClient.dio;
  final NotificationService _notificationService = NotificationService();

  /// Societies for login picker (`GET /public/societies`, no auth). Includes status when present.
  Future<List<({String id, String name, bool isSelectable})>> fetchPublicSocieties() async {
    try {
      final response = await _dio.get(ApiEndpoints.publicSocieties);
      dynamic root = response.data;
      if (root is String && root.trim().isNotEmpty) {
        try {
          root = jsonDecode(root) as Object?;
        } catch (_) {
          throw AppException(message: 'Invalid societies response (not JSON)');
        }
      }
      if (root is! Map) {
        throw AppException(message: 'Invalid societies response');
      }
      final map = Map<String, dynamic>.from(root);
      final rawList = map['societies'];
      if (rawList is! List) {
        throw AppException(message: 'Invalid societies response');
      }
      final out = <({String id, String name, bool isSelectable})>[];
      for (final row in rawList) {
        if (row is Map) {
          final m = Map<String, dynamic>.from(row);
          final id = m['id']?.toString().trim() ?? '';
          final name = m['name']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          final status = m['status']?.toString().trim().toUpperCase();
          final isActive = status == null || status == 'ACTIVE';
          out.add((
            id: id,
            name: name.isEmpty ? id : name,
            isSelectable: isActive,
          ));
        }
      }
      if (kDebugMode) {
        debugPrint('📋 Public societies loaded: ${out.length} (selectable: '
            '${out.where((e) => e.isSelectable).length})');
      }
      return out;
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not load societies',
        ),
      );
    }
  }

  /// Login with username or email and password (tenant `/auth/login`; requires society).
  /// The username parameter accepts both username and email.
  Future<UserModel> login({
    required String societyId,
    required String username,
    required String password,
  }) async {
    try {
      assert(() {
        debugPrint('📡 Calling login API: ${ApiEndpoints.login}');
        debugPrint('📡 Society: $societyId');
        debugPrint('📡 Username/Email: $username');
        return true;
      }());

      // Get device token information
      final deviceInfo = _notificationService.getDeviceTokenInfo();
      assert(() {
        debugPrint('📱 Device Info:');
        debugPrint(
          '   - Token: ${deviceInfo['fcmToken'] != null && deviceInfo['fcmToken']!.length >= 20 ? '${deviceInfo['fcmToken']!.substring(0, 20)}...' : deviceInfo['fcmToken']}',
        );
        debugPrint('   - Device ID: ${deviceInfo['deviceId']}');
        debugPrint('   - Device Type: ${deviceInfo['deviceType']}');
        return true;
      }());
      
      // Normalize Unicode confusables (mathematical monospace/bold/italic/fullwidth
      // variants from Xiaomi and similar keyboards) + strip invisible characters
      // (zero-width spaces, BOM, etc.) that cause "Invalid credentials".
      final cleanPassword = _sanitizeInput(password);
      final cleanUsername = _sanitizeInput(username);

      final payload = <String, dynamic>{
        'societyId': societyId.trim(),
        'username': cleanUsername,
        'password': cleanPassword,
      };
      final fcmToken = deviceInfo['fcmToken'];
      final deviceId = deviceInfo['deviceId'];
      final deviceType = deviceInfo['deviceType'];
      final deviceName = deviceInfo['deviceName'];
      if (fcmToken is String && fcmToken.trim().isNotEmpty) {
        payload['fcmToken'] = fcmToken;
      }
      if (deviceId is String && deviceId.trim().isNotEmpty) {
        payload['deviceId'] = deviceId;
      }
      if (deviceType is String && deviceType.trim().isNotEmpty) {
        payload['deviceType'] = deviceType;
      }
      if (deviceName is String && deviceName.trim().isNotEmpty) {
        payload['deviceName'] = deviceName;
      }

      final response = await _dio.post(
        ApiEndpoints.login,
        data: payload,
      );

      if (kDebugMode) {
        debugPrint('✅ Login API response: ${response.statusCode}');
        debugPrint('✅ Response data keys: ${response.data?.keys}');
      }

      // Validate response structure
      if (response.data == null) {
        throw AppException(message: 'Empty response from server');
      }

      if (response.data['token'] == null) {
        throw AppException(message: 'No token in response');
      }

      if (response.data['user'] == null) {
        throw AppException(message: 'No user data in response');
      }

      // Save tokens
      final token = response.data['token'].toString();
      await StorageService.saveToken(token);
      final refreshToken = response.data['refreshToken']?.toString();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await StorageService.saveRefreshToken(refreshToken);
      }
      if (kDebugMode) {
        debugPrint('✅ Token saved: ${token.substring(0, 20)}...');
      }

      // Parse and save user data
      final userData = Map<String, dynamic>.from(response.data['user']);
      if (kDebugMode) {
        debugPrint('✅ User data fields: ${userData.keys}');
      }

      final sidLogin = societyId.trim();
      if ((userData['societyId']?.toString().trim() ?? '').isEmpty) {
        userData['societyId'] = sidLogin;
      }
      await StorageService.savePreferredLoginSocietyId(sidLogin);

      final user = UserModel.fromJson(userData);
      await StorageService.saveUserData(userData);
      if (kDebugMode) {
        debugPrint('✅ User data saved: ${user.name} (${user.role})');
      }

      await PushSyncService.sync();

      return user;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DioException: ${e.message}');
        debugPrint('❌ Request: ${e.requestOptions.uri}');
        debugPrint('❌ Response: ${e.response?.data}');
        debugPrint('❌ Status: ${e.response?.statusCode}');
      }

      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }

      throw AppException(
        message: parseApiErrorMessage(e.response?.data, 'Login failed'),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Unexpected error: $e');
        debugPrint('❌ Stack trace: ${StackTrace.current}');
      }
      throw AppException(message: 'An unexpected error occurred. Please try again.');
    }
  }

  /// Public: `{ valid, invitation: { … } }` from `GET /invitations/verify/:token`.
  Future<Map<String, dynamic>> verifyInvitationToken(String token) async {
    try {
      final path =
          '/invitations/verify/${Uri.encodeComponent(token.trim())}';
      final response = await _dio.get(path);
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      throw AppException(message: 'Invalid invitation response');
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not verify invitation',
        ),
      );
    }
  }

  Future<UserModel> registerWithInvitation({
    required String token,
    required String username,
    required String name,
    required String email,
    required String password,
    String? phone,
    String? villaId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'token': token.trim(),
        'username': _sanitizeInput(username),
        'name': name.trim(),
        'email': email.trim(),
        'password': _sanitizeInput(password),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (villaId != null && villaId.trim().isNotEmpty)
          'villaId': villaId.trim(),
      };

      final deviceInfo = _notificationService.getDeviceTokenInfo();
      final fcmToken = deviceInfo['fcmToken'];
      final deviceId = deviceInfo['deviceId'];
      final deviceType = deviceInfo['deviceType'];
      final deviceName = deviceInfo['deviceName'];
      if (fcmToken is String && fcmToken.trim().isNotEmpty) {
        payload['fcmToken'] = fcmToken;
      }
      if (deviceId is String && deviceId.trim().isNotEmpty) {
        payload['deviceId'] = deviceId;
      }
      if (deviceType is String && deviceType.trim().isNotEmpty) {
        payload['deviceType'] = deviceType;
      }
      if (deviceName is String && deviceName.trim().isNotEmpty) {
        payload['deviceName'] = deviceName;
      }

      final response =
          await _dio.post(ApiEndpoints.registerWithInvitation, data: payload);

      if (response.data == null) {
        throw AppException(message: 'Empty response from server');
      }

      final root = response.data as Map<String, dynamic>;
      if (root['token'] == null) {
        throw AppException(message: 'No token in response');
      }

      await StorageService.saveToken(root['token'].toString());
      final regRefreshToken = root['refreshToken']?.toString();
      if (regRefreshToken != null && regRefreshToken.isNotEmpty) {
        await StorageService.saveRefreshToken(regRefreshToken);
      }
      final userData = Map<String, dynamic>.from(
        root['user'] as Map<dynamic, dynamic>,
      );

      final sid = userData['societyId']?.toString().trim() ?? '';
      if (sid.isNotEmpty) {
        await StorageService.savePreferredLoginSocietyId(sid);
      }

      final user = UserModel.fromJson(userData);
      await StorageService.saveUserData(userData);
      await PushSyncService.sync();
      return user;
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Registration failed',
        ),
      );
    }
  }

  /// Get current user profile
  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.get(ApiEndpoints.profile);
      final raw = response.data;
      Map<String, dynamic> userData;
      if (raw is Map<String, dynamic>) {
        final nested = raw['user'];
        if (nested is Map) {
          userData = Map<String, dynamic>.from(nested);
        } else {
          userData = Map<String, dynamic>.from(raw);
        }
      } else {
        throw AppException(message: 'Invalid profile response');
      }
      final cached = StorageService.getUserData();
      if ((userData['societyId'] == null || userData['societyId'] == '') &&
          cached != null &&
          cached['societyId'] != null &&
          cached['societyId'].toString().trim().isNotEmpty) {
        userData['societyId'] = cached['societyId'];
      }
      if (userData['society'] == null &&
          cached != null &&
          cached['society'] != null) {
        userData['society'] = cached['society'];
      }
      StorageService.ensureSocietyIdInUserMap(userData);
      final user = UserModel.fromJson(userData);
      
      // Update stored user data
      await StorageService.saveUserData(userData);
      
      return user;
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Failed to fetch profile',
        ),
      );
    }
  }

  /// Email alerts preference (`PATCH /residents/me` with `notifyEmail` only).
  Future<void> updateNotifyEmail(bool notifyEmail) async {
    try {
      await _dio.patch(
        ApiEndpoints.profile,
        data: <String, dynamic>{'notifyEmail': notifyEmail},
      );
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not update email notification preference',
        ),
      );
    }
  }

  /// Push preference (`PATCH /residents/me` with `notifyPush` only).
  Future<void> updateNotifyPush(bool notifyPush) async {
    try {
      await _dio.patch(
        ApiEndpoints.profile,
        data: <String, dynamic>{'notifyPush': notifyPush},
      );
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not update push notification preference',
        ),
      );
    }
  }

  /// Soft-deactivate the resident account (`DELETE /residents/me` with no query).
  ///
  /// The server sets `isActive: false` and disables push devices but retains
  /// the user row + PII so an admin can restore access. Use this for a
  /// reversible "pause" — for store-compliant account *deletion*, call
  /// [hardDeleteAccount] instead.
  Future<void> deactivateAccount() async {
    try {
      await _dio.delete(ApiEndpoints.profile);
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not deactivate account',
        ),
      );
    }
  }

  /// Permanently delete the resident account (`DELETE /residents/me?confirmHardDelete=<name>`).
  ///
  /// The server scrubs PII (name, email, phone, photo, biometric tokens) and
  /// randomises credentials so the user can never sign in again. Financial
  /// and audit records remain intact for the society's accounting trail.
  ///
  /// Required for Apple App Store guideline 5.1.1(v) and Google Play's
  /// User Data policy. The caller must pass the user's full name verbatim;
  /// the server rejects with 400 otherwise.
  Future<void> hardDeleteAccount({required String confirmFullName}) async {
    try {
      await _dio.delete(
        ApiEndpoints.profile,
        queryParameters: <String, dynamic>{
          'confirmHardDelete': confirmFullName,
        },
      );
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not delete account',
        ),
      );
    }
  }

  /// Set a new password while logged in (`PATCH /residents/change-password`).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.changePassword,
        data: <String, dynamic>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }
      throw AppException(
        message: parseApiErrorMessage(
          e.response?.data,
          'Could not change password',
        ),
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await PushSyncService.unregister();
    } catch (_) {
      // Ignore
    }
    try {
      final refreshToken = await StorageService.getRefreshToken();
      await _dio.post(ApiEndpoints.logout, data: {
        if (refreshToken != null && refreshToken.isNotEmpty)
          'refreshToken': refreshToken,
      });
    } catch (e) {
      // Ignore API errors on logout
    } finally {
      // Do NOT call NotificationService().deleteToken() — that destroys the
      // Firebase registration token, so re-login can't send it in the login
      // payload or re-register via PushSyncService.sync().  Backend-side
      // unregister (PushSyncService.unregister above) is sufficient to stop
      // pushes for the old session; the same device token is re-associated
      // with the new user on the next login.
      //
      // Biometric credentials are NOT cleared here — they must survive logout
      // so the biometric button appears on the login screen. They are protected
      // by OS-level biometric auth (fingerprint/face/PIN). They are only
      // cleared when the user explicitly disables biometric in Settings, or
      // when a biometric login attempt fails (stale password).
      await StorageService.clearAll();
      DioClient.reset();
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  /// True when the stored JWT access token has expired (or is missing).
  Future<bool> isTokenExpired() async {
    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return true;
      // Expired if less than 60 seconds remaining.
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          .isBefore(DateTime.now().add(const Duration(seconds: 60)));
    } catch (_) {
      return true;
    }
  }

  /// Proactively refresh the access token using the stored refresh token.
  ///
  /// Returns [RefreshResult.success] when new tokens were persisted,
  /// [RefreshResult.rejected] when the server explicitly rejected the refresh
  /// token (401/403 — it was revoked, expired, or rotated), and
  /// [RefreshResult.networkError] when the call failed for transient reasons
  /// (no internet, timeout, server 500, etc.) so the caller can keep the
  /// session alive with cached data instead of force-logging out.
  Future<RefreshResult> refreshTokens() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return RefreshResult.rejected;
    }
    try {
      // Use a fresh Dio to avoid interceptor loops.
      final freshDio = Dio(BaseOptions(
        baseUrl: DioClient.dio.options.baseUrl,
        connectTimeout: DioClient.dio.options.connectTimeout,
        receiveTimeout: DioClient.dio.options.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ));
      final response = await freshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      final newToken = data['token'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newToken == null || newRefresh == null) {
        return RefreshResult.rejected;
      }
      await StorageService.saveToken(newToken);
      await StorageService.saveRefreshToken(newRefresh);
      return RefreshResult.success;
    } on DioException catch (e) {
      // Server explicitly rejected the refresh token → session is dead.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return RefreshResult.rejected;
      }
      // Network/timeout/5xx — transient failure; session may still be valid.
      return RefreshResult.networkError;
    } catch (_) {
      return RefreshResult.networkError;
    }
  }

  /// Get cached user data
  UserModel? getCachedUser() {
    final userData = StorageService.getUserData();
    if (userData != null) {
      StorageService.ensureSocietyIdInUserMap(userData);
      return UserModel.fromJson(userData);
    }
    return null;
  }

  /// If cached JSON lacked societyId, merge preferred/key and persist once so tenant APIs work.
  Future<void> repairCachedUserDataIfNeeded() async {
    final userData = StorageService.getUserData();
    if (userData == null) return;
    final before = userData['societyId']?.toString().trim() ?? '';
    StorageService.ensureSocietyIdInUserMap(userData);
    final after = userData['societyId']?.toString().trim() ?? '';
    if (after.isNotEmpty && after != before) {
      await StorageService.saveUserData(userData);
    }
  }
}
