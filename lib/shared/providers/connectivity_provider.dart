import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has network connectivity.
///
/// Emits `true` when Wi-Fi, mobile, ethernet, or VPN is available and `false`
/// when the device reports no connection. The initial value is `true` (assume
/// online until told otherwise) so the banner doesn't flash on cold start.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

  return connectivity.onConnectivityChanged.map(_isOnline);
});
