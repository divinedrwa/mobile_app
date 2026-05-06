import 'package:flutter/widgets.dart';

import '../logging/fcm_log.dart';
import 'notification_service.dart';
import 'push_sync_service.dart';

/// Re-syncs FCM registration when the app resumes and applies cold-start deep links.
class PushLifecycleBinding extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fcmDiag('LIFECYCLE', 'app resumed → flushPendingNavigation + PushSync');
      NotificationService().flushPendingNavigation();
      PushSyncService.sync();
    }
  }
}
