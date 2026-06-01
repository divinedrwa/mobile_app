import 'package:web/web.dart' as html;

/// Shows a browser notification using the Web Notifications API.
void showWebNotification(String title, String body, Map<String, String> data) {
  try {
    if (html.Notification.permission != 'granted') return;

    final options = html.NotificationOptions(
      body: body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
    );
    html.Notification(title, options);
  } catch (_) {
    // Silently ignore — browser may not support Notification API.
  }
}
