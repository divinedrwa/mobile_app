import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'guard_flow_telemetry.dart';

/// Binds [GuardFlowTelemetry] to console + optional Firebase Analytics.
void registerGuardFlowTelemetry({required bool firebaseAvailable}) {
  GuardFlowTelemetry.onFlowComplete =
      (String flowId, Duration duration, {required bool success}) {
    debugPrint(
      '[GuardTelemetry] flow=$flowId ms=${duration.inMilliseconds} success=$success',
    );
    if (!firebaseAvailable) return;
    _logToAnalytics(flowId, duration, success: success);
  };
}

Future<void> _logToAnalytics(
  String flowId,
  Duration duration, {
  required bool success,
}) async {
  try {
    await FirebaseAnalytics.instance.logEvent(
      name: 'guard_flow_complete',
      parameters: {
        'flow_id': flowId,
        'duration_ms': duration.inMilliseconds,
        'success': success,
      },
    );
  } catch (e) {
    assert(() {
      debugPrint('[GuardAnalytics] log skipped: $e');
      return true;
    }());
  }
}
