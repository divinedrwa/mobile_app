import 'package:flutter/material.dart';

import 'analytics_screen_names.dart';
import 'app_analytics_service.dart';
import 'telemetry_safe.dart';

/// Logs GoRouter screen transitions to first-party + Firebase analytics.
class AppAnalyticsRouteObserver extends NavigatorObserver {
  String? _lastPath;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _trackRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _trackRoute(previousRoute);
    super.didPop(route, previousRoute);
  }

  void _trackRoute(Route<dynamic> route) {
    final path = _pathFromRoute(route);
    if (path == null || path.isEmpty || path == _lastPath) return;
    _lastPath = path;
    runTelemetrySafe(() => AppAnalyticsService.logScreen(path), label: 'screen');
  }

  String? _pathFromRoute(Route<dynamic> route) {
    final name = route.settings.name?.trim();
    if (name != null && name.isNotEmpty && name.startsWith('/')) return name;

    final args = route.settings.arguments;
    if (args is Map && args['location'] is String) {
      return args['location'] as String;
    }

    if (name != null && name.isNotEmpty) return name;
    return null;
  }
}

/// Exposed for tests and tab paths that bypass GoRouter.
String analyticsScreenLabel(String path) => AnalyticsScreenNames.labelForPath(path);
