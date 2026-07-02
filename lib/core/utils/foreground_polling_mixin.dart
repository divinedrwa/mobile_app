import 'dart:async';

import 'package:flutter/widgets.dart';

/// Drives a periodic callback that runs **only while the app is foregrounded**
/// and the screen is mounted.
///
/// Screens used to arm a bare `Timer.periodic`, which keeps hitting the API
/// every few seconds even when the phone is locked or the app is in the
/// background — pure wasted battery and data. This mixin gates the timer on
/// [AppLifecycleState]: it pauses when the app leaves the foreground and, on
/// resume, fires one immediate tick (so the screen is fresh) before re-arming.
/// Pair it with a pull-to-refresh for the manual path.
///
/// Usage:
/// ```dart
/// class _MyPageState extends ConsumerState<MyPage>
///     with ForegroundPollingMixin {
///   @override
///   Duration get pollInterval => const Duration(seconds: 15);
///   @override
///   void onPollTick() => ref.invalidate(someProvider);
///
///   @override
///   void initState() {
///     super.initState();
///     startForegroundPolling();
///   }
///   @override
///   void dispose() {
///     stopForegroundPolling();
///     super.dispose();
///   }
/// }
/// ```
mixin ForegroundPollingMixin<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  _ForegroundLifecycleObserver? _observer;

  /// How often to tick while foregrounded.
  Duration get pollInterval;

  /// Called on each foreground tick and once immediately on app resume.
  void onPollTick();

  /// Whether polling is currently allowed. Screens can override to suspend
  /// ticks conditionally (e.g. while a decision is in flight). Defaults to on.
  bool get shouldPoll => true;

  void startForegroundPolling() {
    _observer = _ForegroundLifecycleObserver(
      onResume: () {
        if (!mounted) return;
        _tick();
        _arm();
      },
      onLeaveForeground: _disarm,
    );
    WidgetsBinding.instance.addObserver(_observer!);
    _arm();
  }

  void stopForegroundPolling() {
    _disarm();
    if (_observer != null) {
      WidgetsBinding.instance.removeObserver(_observer!);
      _observer = null;
    }
  }

  void _arm() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _tick());
  }

  void _disarm() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _tick() {
    if (!mounted || !shouldPoll) return;
    onPollTick();
  }
}

class _ForegroundLifecycleObserver extends WidgetsBindingObserver {
  _ForegroundLifecycleObserver({
    required this.onResume,
    required this.onLeaveForeground,
  });

  final VoidCallback onResume;
  final VoidCallback onLeaveForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    } else {
      // paused / inactive / hidden / detached — stop hitting the network.
      onLeaveForeground();
    }
  }
}
