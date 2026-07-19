import 'package:flutter/material.dart';

import 'app_analytics_service.dart';

/// Logs GoRouter screen transitions to first-party analytics.
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

  void _trackRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == _lastPath) return;
    _lastPath = name;
    AppAnalyticsService.logScreen(name);
  }
}
