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
import 'analytics_screen_names.dart';
import 'firebase_analytics_helper.dart';
import 'telemetry_safe.dart';

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
    try {
      _user = user;
      runTelemetrySafe(() => FirebaseAnalyticsHelper.setUser(user), label: 'setUser');
    } catch (_) {}
  }

  static void clearUserContext() {
    try {
      _user = null;
      runTelemetrySafe(() => FirebaseAnalyticsHelper.setUser(null), label: 'clearUser');
    } catch (_) {}
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
    unawaited(
      FirebaseAnalyticsHelper.setAppContext(
        platform: _platform ?? 'unknown',
        appVersion: _appVersion ?? 'unknown',
        buildNumber: _buildNumber,
      ),
    );
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
    try {
      await ensureMetaLoaded();
      await _flushPending();
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
      runTelemetrySafe(FirebaseAnalyticsHelper.logSessionStart, label: 'sessionStart');
    } catch (e) {
      assert(() {
        debugPrint('[AppAnalytics] startSession failed: $e');
        return true;
      }());
    }
  }

  static Future<void> heartbeat() async {
    try {
      final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
      if (sid == null || sid.isEmpty) {
        await startSession();
        return;
      }
      _sessionId = sid;
      await _dio.patch(ApiEndpoints.appAnalyticsSession(sid), data: {'heartbeat': true});
    } catch (_) {}
  }

  static Future<void> endSession() async {
    try {
      final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
      if (sid == null || sid.isEmpty) return;
      await _dio.patch(ApiEndpoints.appAnalyticsSession(sid), data: {'ended': true});
      runTelemetrySafe(FirebaseAnalyticsHelper.logSessionEnd, label: 'sessionEnd');
      _sessionId = null;
      await StorageService.remove(_sessionIdKey);
    } catch (_) {}
  }

  static Future<void> logSessionEnd() async {
    try {
      final sid = _sessionId ?? StorageService.getString(_sessionIdKey);
      if (sid == null || sid.isEmpty) return;
      await _logEvent(
        kind: 'SESSION_END',
        name: 'session_end',
        clientEventId: 'sess-end-$sid',
      );
      runTelemetrySafe(FirebaseAnalyticsHelper.logSessionEnd, label: 'sessionEnd');
    } catch (_) {}
  }

  static Future<void> logTabScreen(String path) => logScreen(path);

  static Future<void> logLogin() async {
    try {
      await _logEvent(kind: 'LOGIN', name: 'login_success');
      runTelemetrySafe(
        () => FirebaseAnalyticsHelper.logLogin(method: _user?.role.name ?? 'app'),
        label: 'login',
      );
    } catch (_) {}
  }

  static Future<void> logLogout() async {
    try {
      await _logEvent(kind: 'LOGOUT', name: 'logout');
      runTelemetrySafe(FirebaseAnalyticsHelper.logLogout, label: 'logout');
    } catch (_) {}
  }

  static Future<void> logScreen(String routePath) async {
    try {
      runTelemetrySafe(
        () => FirebaseAnalyticsHelper.logScreenView(routePath),
        label: 'screenView',
      );
      final label = AnalyticsScreenNames.labelForPath(routePath);
      await _logEvent(
        kind: 'SCREEN_VIEW',
        name: routePath,
        properties: {'screenLabel': label},
      );
    } catch (_) {}
  }

  static Future<void> logNotificationReceive({
    required String type,
    String? title,
  }) async {
    try {
      runTelemetrySafe(
        () => FirebaseAnalyticsHelper.logNotificationReceive(type: type, title: title),
        label: 'notificationReceive',
      );
      await _logEvent(
        kind: 'ACTION',
        name: 'notification_receive',
        properties: {
          'notificationType': type,
          if (title != null) 'title': title,
        },
      );
    } catch (_) {}
  }

  static Future<void> logNotificationOpen({
    required String type,
    String source = 'tap',
  }) async {
    try {
      runTelemetrySafe(
        () => FirebaseAnalyticsHelper.logNotificationOpen(type: type, source: source),
        label: 'notificationOpen',
      );
      await _logEvent(
        kind: 'ACTION',
        name: 'notification_open',
        properties: {
          'notificationType': type,
          'source': source,
        },
      );
    } catch (_) {}
  }

  static Future<void> logFlow({
    required String flowId,
    required int durationMs,
    required bool success,
  }) async {
    try {
      await _logEvent(
        kind: 'FLOW_COMPLETE',
        name: flowId,
        durationMs: durationMs,
        success: success,
      );
    } catch (_) {}
  }

  static Future<void> logAction(String action, {Map<String, dynamic>? properties}) async {
    try {
      await _logEvent(kind: 'ACTION', name: action, properties: properties);
    } catch (_) {}
  }

  static Future<void> logError(String name, {Map<String, dynamic>? properties}) async {
    try {
      await _logEvent(kind: 'ERROR', name: name, success: false, properties: properties);
    } catch (_) {}
  }

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
