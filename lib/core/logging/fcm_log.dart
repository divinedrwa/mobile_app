import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Central FCM diagnostics. Filter logcat:
/// `adb logcat | grep DivineFCM`
const String divineFcmTag = '[DivineFCM]';

void fcmDiag(String phase, String message,
    [Object? err, StackTrace? stackTrace]) {
  final line = '$divineFcmTag $phase: $message';
  developer.log(
    line,
    name: 'DivineFCM',
    level: err != null ? 1000 : 800,
    error: err,
    stackTrace: stackTrace,
  );
  if (kDebugMode) {
    debugPrint(line);
    if (err != null) {
      debugPrint('$divineFcmTag err=$err');
    }
  }
  // Release/profile: developer.log (above) writes to the structured dart
  // log which is NOT visible via logcat to other apps. No print() fallback.
}

String describeRemoteMessage(RemoteMessage m) {
  final n = m.notification;
  final notifDesc = n == null
      ? 'notification=null'
      : 'notification(title="${n.title}", body="${n.body}", '
          'android=${n.android?.channelId ?? "-"}, ios=${n.apple?.subtitle ?? "-"})';

  final dataPreview = () {
    if (m.data.isEmpty) return 'data={}';
    final entries =
        m.data.entries.map((e) => '${e.key}="${e.value}"').join(', ');
    return 'data={$entries}';
  }();

  final collapse = 'collapse=${m.collapseKey ?? "none"}';
  final from = 'from="${m.from ?? ""}"';

  return 'messageId="${m.messageId ?? ""}" | sent=${m.sentTime?.toUtc().toIso8601String() ?? "?"}, '
      '$from | $collapse | $notifDesc | $dataPreview';
}
