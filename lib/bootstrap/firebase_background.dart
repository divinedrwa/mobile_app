import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/logging/fcm_log.dart';
import '../core/services/notification_service.dart' as notif;
import '../firebase_options.dart';

/// Entry registered with [FirebaseMessaging.onBackgroundMessage].
/// Inits Firebase in the background isolate, then delegates to [notif.firebaseMessagingBackgroundHandler].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundEntry(RemoteMessage message) async {
  fcmDiag('MAIN_BG_HANDLER', 'entry (before Firebase.initializeApp)');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    fcmDiag('MAIN_BG_HANDLER', 'Firebase.initializeApp OK in isolate');
  } catch (e, st) {
    fcmDiag('MAIN_BG_HANDLER_FAIL', 'Firebase.initializeApp in isolate', e, st);
  }
  await notif.firebaseMessagingBackgroundHandler(message);
}
