import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has network connectivity.
///
/// Emits `true` when Wi-Fi, mobile, ethernet, or VPN is available and `false`
/// when the device reports no connection. The stream starts with a synchronous
/// check so consumers get a value immediately (no flash of "offline" banner).
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  bool isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

  // Emit the current state first, then follow with the change stream.
  final controller = StreamController<bool>();

  connectivity.checkConnectivity().then((results) {
    if (!controller.isClosed) controller.add(isOnline(results));
  });

  final sub = connectivity.onConnectivityChanged.listen(
    (results) {
      if (!controller.isClosed) controller.add(isOnline(results));
    },
    onError: (Object e) {
      if (!controller.isClosed) controller.addError(e);
    },
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
