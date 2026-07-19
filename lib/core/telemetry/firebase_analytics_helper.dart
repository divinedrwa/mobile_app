import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/user_model.dart';
import 'analytics_screen_names.dart';

/// Mirrors key custom analytics events to Firebase Analytics (Spark / free tier).
///
/// Free automatic metrics in Firebase console: DAU/WAU/MAU, retention, country,
/// device model, app version, engagement time, `first_open`, `user_engagement`,
/// `notification_receive`, Crashlytics crash-free users.
class FirebaseAnalyticsHelper {
  FirebaseAnalyticsHelper._();

  static bool _available = false;
  static bool _initialized = false;

  static void configure({required bool available}) {
    _available = available;
    if (available) {
      unawaited(_initOnce());
    }
  }

  static bool get isAvailable => _available;

  static Future<void> _initOnce() async {
    if (_initialized || !_available) return;
    _initialized = true;
    try {
      // Stop Android from logging "MainActivity" — we send named screen_view instead.
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      assert(() {
        debugPrint('[FirebaseAnalytics] init skipped: $e');
        return true;
      }());
    }
  }

  static Future<void> setAppContext({
    required String platform,
    required String appVersion,
    String? buildNumber,
  }) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'app_platform',
        value: platform.toLowerCase(),
      );
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'app_version',
        value: appVersion,
      );
      if (buildNumber != null && buildNumber.isNotEmpty) {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'build_number',
          value: buildNumber,
        );
      }
    } catch (_) {}
  }

  static Future<void> setUser(UserModel? user) async {
    if (!_available) return;
    try {
      if (user == null) {
        await FirebaseAnalytics.instance.setUserId(id: null);
        return;
      }
      await FirebaseAnalytics.instance.setUserId(id: user.id);
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'user_role',
        value: user.role.name,
      );
      final societyId = user.societyId;
      if (societyId.isNotEmpty) {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'society_id',
          value: societyId,
        );
      }
      if (user.villaNumber != null && user.villaNumber!.isNotEmpty) {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'villa_number',
          value: user.villaNumber,
        );
      }
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'account_active',
        value: user.isActive ? 'true' : 'false',
      );
    } catch (e) {
      assert(() {
        debugPrint('[FirebaseAnalytics] setUser skipped: $e');
        return true;
      }());
    }
  }

  static Future<void> logLogin({required String method}) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logLogin(loginMethod: method);
    } catch (_) {}
  }

  static Future<void> logLogout() async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: 'logout');
    } catch (_) {}
  }

  static Future<void> logScreenView(String routePath) async {
    if (!_available) return;
    try {
      final screen = _sanitizeName(AnalyticsScreenNames.labelForPath(routePath));
      await FirebaseAnalytics.instance.logScreenView(
        screenName: screen,
        screenClass: AnalyticsScreenNames.screenClass,
      );
    } catch (_) {}
  }

  static Future<void> logSessionStart() async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: 'session_start');
    } catch (_) {}
  }

  static Future<void> logSessionEnd() async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: 'session_end');
    } catch (_) {}
  }

  static Future<void> logNotificationReceive({
    required String type,
    String? title,
  }) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'notification_receive',
        parameters: {
          'notification_type': _sanitizeName(type.isEmpty ? 'general' : type),
          if (title != null && title.isNotEmpty)
            'notification_title': title.length > 100 ? title.substring(0, 100) : title,
        },
      );
    } catch (_) {}
  }

  static Future<void> logNotificationOpen({
    required String type,
    String source = 'tap',
  }) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'notification_open',
        parameters: {
          'notification_type': _sanitizeName(type.isEmpty ? 'general' : type),
          'open_source': _sanitizeName(source),
        },
      );
    } catch (_) {}
  }

  static Future<void> logFlowComplete({
    required String flowId,
    required int durationMs,
    required bool success,
  }) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'guard_flow_complete',
        parameters: {
          'flow_id': _sanitizeName(flowId),
          'duration_ms': durationMs,
          'success': success,
        },
      );
    } catch (_) {}
  }

  static Future<void> logCustomEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: _sanitizeName(name),
        parameters: parameters,
      );
    } catch (_) {}
  }

  static Future<void> logBusinessAction({
    required String action,
    bool success = true,
    Map<String, dynamic>? properties,
  }) async {
    if (!_available) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'business_action',
        parameters: {
          'action': _sanitizeName(action),
          'success': success,
          if (properties != null)
            ...properties.map(
              (k, v) => MapEntry(
                _sanitizeName(k),
                v is num || v is String ? v : v.toString(),
              ),
            ),
        },
      );
    } catch (_) {}
  }

  static String _sanitizeName(String raw) {
    var s = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    if (s.length > 40) s = s.substring(0, 40);
    if (s.isEmpty) s = 'unknown';
    return s;
  }
}
