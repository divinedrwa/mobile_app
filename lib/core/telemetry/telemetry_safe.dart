import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs telemetry work without letting failures crash or block the app.
void runTelemetrySafe(Future<void> Function() action, {String? label}) {
  unawaited(
    action().catchError((Object error, StackTrace stack) {
      assert(() {
        debugPrint(
          '[Telemetry${label != null ? ' $label' : ''}] skipped: $error',
        );
        return true;
      }());
    }),
  );
}

/// Safe first letter for avatars — never throws on empty names.
String telemetrySafeInitial(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

Map<String, dynamic> telemetrySafeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

List<Map<String, dynamic>> telemetrySafeMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(telemetrySafeMap)
      .where((m) => m.isNotEmpty || m.containsKey('userId'))
      .toList();
}
