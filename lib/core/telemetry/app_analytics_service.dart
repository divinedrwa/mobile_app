import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/user_model.dart';
import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';
import '../utils/platform_info.dart' as platform_info;
import '../utils/storage_service.dart';
import 'firebase_analytics_helper.dart';

/// First-party app usage telemetry (backend) + optional Firebase Analytics mirror.
class AppAnalyticsService {
  AppAnalyticsService._();

  static const _sessionIdKey = 'app_analytics_session_id';
  static const _deviceIdKey = 'app_analytics_device_id';
  static const _pendingEventsKey = 'app_analytics_pending_events_v1';
  static const _uuid = Uuid();

  static String? _sessionId;
  static String? _platform;
  static String? _appVersion;
  static String? _buildNumber;
  static bool _metaLoaded = false;
  static UserModel? _user;

  static Dio get _dio => DioClient.dio;

  static void setUserContext(UserModel user) {
    _user = user;
    unawaited(FirebaseAnalyticsHelper.setUser(user));
  }

  static void clearUserContext() {
    _user = null;
    unawaited(FirebaseAnalyticsHelper.setUser(null));
  }

  static Map<String, dynamic> _userProperties() {
    final u = _user;
    if (u == null) return {};
    return {
      'userId': u.id,
      'userName': u.name,
      'username': u.username,
      'role': u.role.name,
      'societyId': u.societyId,
      if (u.villaNumber != null) 'villaNumber': u.villaNumber,
      'userIsActive': u.isActive,
    };
  }

  static Future<void> ensureMetaLoaded() async {
    if (_metaLoaded) return;
    _platform = _resolvePlatform();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      _appVersion ??= 'unknown';
    }
    _metaLoaded = true;
  }

  static String _resolvePlatform() {
    if (kIsWeb) return 'WEB';
    if (platform_info.isIOS) return 'IOS';
    return 'ANDROID';
  }

  static Future<String> _deviceId() async {
    final existing = StorageService.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await StorageService.setString(_deviceIdKey, id);
    return id;
  }

  static Future<Map<String, String?>> _deviceMeta() async {
    String? model;
    String? osVersion;
    try {
      if (kIsWeb) {
        model = 'web';
      } else if (platform_info.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        model = '${a.manufacturer} ${a.model}';
        osVersion = 'Android ${a.version.release}';
      } else if (platform_info.isIOS) {
        final i = await DeviceInfoPlugin().iosInfo;
        model = i.utsname.machine;
        osVersion = '${i.systemName} ${i.systemVersion}';
      }
    } catch (_) {}
    return {'deviceModel': model, 'osVersion': osVersion};
  }

  /// Start a session after login or cold start with valid auth.
  static Future<void> startSession() async {
    await ensureMetaLoaded();
    await _flushPending();
    try {
      final meta = await _deviceMeta();
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsSessions,
        data: {
          'platform': _platform,
          'appVersion': _appVersion,
          'buildNumber': _buildNumber,
          'deviceId': await _deviceId(),
          'deviceModel': meta['deviceModel'],
          'osVersion': meta['osVersion'],
        },
      );
      final session = res.data?['session'];
      if (session is Map && session['id'] is String) {
        _sessionId = session['id'] as String;
        await StorageService.setString(_sessionIdKey, _sessionId!);
      }
      unawaited(FirebaseAnalyticsHelper.logSessionStart());
    } catch (e) {
      assert(() {
        debugPrint('[AppAnalytics] startSession failed: $e');
        return true;
      }());
    }
  }

  static Future<void> heartbeat() async {
    final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
    if (sid == null || sid.isEmpty) {
      await startSession();
      return;
    }
    _sessionId = sid;
    try {
      await _dio.patch(ApiEndpoints.appAnalyticsSession(sid), data: {'heartbeat': true});
    } catch (_) {}
  }

  static Future<void> endSession() async {
    final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
    if (sid == null || sid.isEmpty) return;
    try {
      await logSessionEnd();
      await _dio.patch(ApiEndpoints.appAnalyticsSession(sid), data: {'ended': true});
    } catch (_) {}
    _sessionId = null;
    await StorageService.remove(_sessionIdKey);
  }

  static Future<void> logSessionEnd() async {
    final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
    if (sid == null || sid.isEmpty) return;
    await _logEvent(
      kind: 'SESSION_END',
      name: 'session_end',
      clientEventId: 'sess-end-$sid',
    );
    unawaited(FirebaseAnalyticsHelper.logSessionEnd());
  }

  static Future<void> logTabScreen(String path) => logScreen(path);

  static Future<void> logLogin() async {
    await _logEvent(kind: 'LOGIN', name: 'login_success');
    unawaited(FirebaseAnalyticsHelper.logLogin(method: _user?.role.name ?? 'app'));
  }

  static Future<void> logLogout() async {
    await _logEvent(kind: 'LOGOUT', name: 'logout');
    unawaited(FirebaseAnalyticsHelper.logLogout());
  }

  static Future<void> logScreen(String routePath) {
    unawaited(FirebaseAnalyticsHelper.logScreenView(routePath));
    return _logEvent(kind: 'SCREEN_VIEW', name: routePath);
  }

  static Future<void> logFlow({
    required String flowId,
    required int durationMs,
    required bool success,
  }) =>
      _logEvent(
        kind: 'FLOW_COMPLETE',
        name: flowId,
        durationMs: durationMs,
        success: success,
      );

  static Future<void> logAction(String action, {Map<String, dynamic>? properties}) =>
      _logEvent(kind: 'ACTION', name: action, properties: properties);

  static Future<void> logError(String name, {Map<String, dynamic>? properties}) =>
      _logEvent(kind: 'ERROR', name: name, success: false, properties: properties);

  static Future<void> _logEvent({
    required String kind,
    required String name,
    int? durationMs,
    bool? success,
    Map<String, dynamic>? properties,
    String? clientEventId,
  }) async {
    await ensureMetaLoaded();
    final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
    final mergedProps = {
      ..._userProperties(),
      if (properties != null) ...properties,
    };
    final payload = {
      'kind': kind,
      'name': name,
      'clientEventId': clientEventId ?? _uuid.v4(),
      'platform': _platform,
      'appVersion': _appVersion,
      if (sid != null) 'sessionId': sid,
      if (durationMs != null) 'durationMs': durationMs,
      if (success != null) 'success': success,
      if (mergedProps.isNotEmpty) 'properties': mergedProps,
    };
    try {
      await _dio.post(ApiEndpoints.appAnalyticsEvents, data: payload);
    } catch (_) {
      await _enqueuePending(payload);
    }
  }

  static Future<void> _enqueuePending(Map<String, dynamic> payload) async {
    try {
      final raw = StorageService.getString(_pendingEventsKey);
      final list = raw != null && raw.isNotEmpty
          ? (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (list.length >= 100) list.removeAt(0);
      list.add(payload);
      await StorageService.setString(_pendingEventsKey, jsonEncode(list));
    } catch (_) {}
  }

  static Future<void> _flushPending() async {
    try {
      final raw = StorageService.getString(_pendingEventsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isEmpty) return;
      await _dio.post(ApiEndpoints.appAnalyticsEventsBatch, data: {'events': list});
      await StorageService.remove(_pendingEventsKey);
    } catch (_) {}
  }
}
