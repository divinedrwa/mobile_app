import 'app_analytics_service.dart';
import 'business_analytics.dart';
import 'firebase_analytics_helper.dart';
import 'guard_flow_telemetry.dart';
import 'telemetry_safe.dart';

/// Registers dual telemetry: every guard flow and business action is written to
/// **custom backend** (society dashboard) and **Firebase Analytics** (GA4 mirror).
void registerUnifiedAppTelemetry({required bool firebaseAvailable}) {
  FirebaseAnalyticsHelper.configure(available: firebaseAvailable);

  GuardFlowTelemetry.onFlowComplete =
      (String flowId, Duration duration, {required bool success}) {
    runTelemetrySafe(
      () => AppAnalyticsService.logFlow(
        flowId: flowId,
        durationMs: duration.inMilliseconds,
        success: success,
      ),
      label: 'flow-backend',
    );
    runTelemetrySafe(
      () => FirebaseAnalyticsHelper.logFlowComplete(
        flowId: flowId,
        durationMs: duration.inMilliseconds,
        success: success,
      ),
      label: 'flow-firebase',
    );
  };
}

/// Convenience export so callers import one module for growth tracking.
typedef UnifiedBusinessAnalytics = BusinessAnalytics;
