import 'package:flutter/material.dart';

/// Key used by the root [ValueListenableBuilder] in main.dart.
/// Changing it forces the entire widget tree (including [ProviderScope])
/// to be recreated — a clean app restart without killing the process.
final appRestartKey = ValueNotifier<Key>(UniqueKey());

/// Triggers a full app restart. All Riverpod providers, GoRouter state,
/// Dio instances, and in-memory caches are destroyed. The app starts
/// fresh from the splash screen, which reads persisted preferences
/// (preferred society, API URL, etc.) and navigates accordingly.
void restartApp() {
  appRestartKey.value = UniqueKey();
}
