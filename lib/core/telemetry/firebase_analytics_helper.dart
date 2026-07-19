import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/user_model.dart';

/// Mirrors key custom analytics events to Firebase Analytics (free tier).
class FirebaseAnalyticsHelper {
  FirebaseAnalyticsHelper._();

  static bool _available = false;

  static void configure({required bool available}) {
    _available = available;
  }

  static bool get isAvailable => _available;

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
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'society_id',
        value: user.societyId,
      );
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
      final screen = _sanitizeName(routePath);
      await FirebaseAnalytics.instance.logScreenView(screenName: screen);
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

  static String _sanitizeName(String raw) {
    var s = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    if (s.length > 40) s = s.substring(0, 40);
    if (s.isEmpty) s = 'unknown';
    return s;
  }
}
