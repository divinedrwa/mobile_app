import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_analytics_service.dart';
import 'firebase_analytics_helper.dart';
import 'guard_flow_telemetry.dart';

/// Guard flows + session events go to both Firebase Analytics and our backend.
void registerUnifiedAppTelemetry({required bool firebaseAvailable}) {
  FirebaseAnalyticsHelper.configure(available: firebaseAvailable);

  GuardFlowTelemetry.onFlowComplete =
      (String flowId, Duration duration, {required bool success}) {
    debugPrint(
      '[Telemetry] flow=$flowId ms=${duration.inMilliseconds} success=$success',
    );
    unawaited(
      AppAnalyticsService.logFlow(
        flowId: flowId,
        durationMs: duration.inMilliseconds,
        success: success,
      ),
    );
    unawaited(
      FirebaseAnalyticsHelper.logFlowComplete(
        flowId: flowId,
        durationMs: duration.inMilliseconds,
        success: success,
      ),
    );
  };
}
