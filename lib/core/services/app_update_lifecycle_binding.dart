import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/platform_info.dart' as platform_info;
import 'app_version_service.dart';
import 'in_app_update_wrapper.dart';

/// Resumes a Play in-app immediate update that was interrupted when the
/// process was killed mid-install (common after Play applies an APK).
///
/// The in_app_update plugin only auto-resumes when [appUpdateType] is still
/// in memory; after a cold start we must call [checkForUpdate] again from Dart.
class AppUpdateLifecycleBinding extends WidgetsBindingObserver {
  bool _checking = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !platform_info.isAndroid) {
      return;
    }
    if (_checking) return;
    _checking = true;
    unawaited(_resumeIfNeeded().whenComplete(() => _checking = false));
  }

  Future<void> _resumeIfNeeded() async {
    final result = await AppVersionService.resumeInterruptedImmediateUpdate();
    if (result == AppUpdateResult.success) {
      // Play takes over; process may exit — nothing else to do here.
    }
  }
}
