import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps a provider alive for [duration] after the last listener detaches,
/// then auto-invalidates to force a fresh fetch on next read.
///
/// Usage inside a `FutureProvider.autoDispose`:
/// ```dart
/// final myProvider = FutureProvider.autoDispose<Data>((ref) async {
///   cacheFor(ref, const Duration(minutes: 5));
///   return fetchData();
/// });
/// ```
void cacheFor(AutoDisposeRef<Object?> ref, Duration duration) {
  final link = ref.keepAlive();
  Timer? timer;

  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(duration, () {
      link.close(); // allow dispose
      ref.invalidateSelf(); // force refresh on next read
    });
  });
  ref.onResume(() {
    timer?.cancel();
  });
}
