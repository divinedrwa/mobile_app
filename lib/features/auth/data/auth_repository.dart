import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/security/secure_credentials_store.dart';
import '../../../core/utils/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/push_sync_service.dart';
import '../../../shared/models/user_model.dart';

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
      debugPrint('📡 Calling login API: ${ApiEndpoints.login}');
      debugPrint('📡 Society: $societyId');
      debugPrint('📡 Username/Email: $username');
      
      // Get device token information
      final deviceInfo = _notificationService.getDeviceTokenInfo();
      debugPrint('📱 Device Info:');
      debugPrint(
        '   - Token: ${deviceInfo['fcmToken'] != null && deviceInfo['fcmToken']!.length >= 20 ? '${deviceInfo['fcmToken']!.substring(0, 20)}...' : deviceInfo['fcmToken']}',
      );
      debugPrint('   - Device ID: ${deviceInfo['deviceId']}');
      debugPrint('   - Device Type: ${deviceInfo['deviceType']}');
      
      final payload = <String, dynamic>{
        'societyId': societyId.trim(),
        'username': username,
        'password': password,
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

      debugPrint('✅ Login API response: ${response.statusCode}');
      debugPrint('✅ Response data keys: ${response.data?.keys}');

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

      // Save token
      final token = response.data['token'].toString();
      await StorageService.saveToken(token);
      debugPrint('✅ Token saved: ${token.substring(0, 20)}...');

      // Parse and save user data
      final userData = Map<String, dynamic>.from(response.data['user']);
      debugPrint('✅ User data fields: ${userData.keys}');

      final sidLogin = societyId.trim();
      if ((userData['societyId']?.toString().trim() ?? '').isEmpty) {
        userData['societyId'] = sidLogin;
      }
      await StorageService.savePreferredLoginSocietyId(sidLogin);

      final user = UserModel.fromJson(userData);
      await StorageService.saveUserData(userData);
      debugPrint('✅ User data saved: ${user.name} (${user.role})');

      await PushSyncService.sync();

      return user;
    } on DioException catch (e) {
      debugPrint('❌ DioException: ${e.message}');
      debugPrint('❌ Request: ${e.requestOptions.uri}');
      debugPrint('❌ Response: ${e.response?.data}');
      debugPrint('❌ Status: ${e.response?.statusCode}');

      final wrapped = e.error;
      if (wrapped is AppException) {
        throw wrapped;
      }

      throw AppException(
        message: parseApiErrorMessage(e.response?.data, 'Login failed'),
      );
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      throw AppException(message: 'Unexpected error: $e');
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
        'username': username.trim(),
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
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

  /// Soft-delete resident account (`DELETE /residents/me`) — sets `isActive: false` on server.
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
      await _dio.post(ApiEndpoints.logout);
    } catch (e) {
      // Ignore API errors on logout
    } finally {
      await NotificationService().deleteToken();
      await SecureCredentialsStore.instance.clearCredentials();
      await StorageService.clearAll();
      DioClient.reset();
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
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
