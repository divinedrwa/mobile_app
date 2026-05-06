import 'package:flutter/foundation.dart';

/// Tap-to-complete timing for guard flows. Wire [onFlowComplete] to Analytics/Firebase.
class GuardFlowTelemetry {
  GuardFlowTelemetry._();

  /// Optional hook: Analytics.logEvent, Crashlytics, etc.
  static void Function(String flowId, Duration duration, {required bool success})?
      onFlowComplete;

  static FlowTimerSpan start(String flowId) =>
      FlowTimerSpan._(flowId, DateTime.now());
}

class FlowTimerSpan {
  FlowTimerSpan._(this.flowId, this._startedAt);

  final String flowId;
  final DateTime _startedAt;

  void complete({bool success = true}) {
    final d = DateTime.now().difference(_startedAt);
    GuardFlowTelemetry.onFlowComplete?.call(flowId, d, success: success);
    assert(() {
      debugPrint(
        '[GuardFlowTelemetry] $flowId ${d.inMilliseconds}ms success=$success',
      );
      return true;
    }());
  }
}
