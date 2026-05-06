import '../constants/api_endpoints.dart';
import '../logging/fcm_log.dart';
import '../network/dio_client.dart';
import '../utils/notification_preference_storage.dart';
import '../utils/storage_service.dart';
import 'notification_service.dart';

/// Keeps FCM registration aligned with backend `PushDevice` (stable [deviceId] + current token).
class PushSyncService {
  PushSyncService._();

  /// Call after login and when the app returns to foreground (token may have refreshed).
  static Future<void> sync() async {
    final token = StorageService.getToken();
    if (token == null || token.isEmpty) {
      fcmDiag('API_REGISTER', 'skip: no JWT (user not logged in)');
      return;
    }

    if (!NotificationPreferenceStorage.shouldDeliverPush) {
      fcmDiag(
        'API_REGISTER',
        'skip: user disabled notifications/push → deactivate device',
      );
      await unregister();
      return;
    }

    final svc = NotificationService();
    if (!svc.isPushBackendReady) {
      final info = svc.getDeviceTokenInfo();
      fcmDiag(
        'API_REGISTER',
        'skip: push not ready '
            'placeholder=${svc.isPlaceholderToken} '
            'fcmLen=${info['fcmToken']?.length ?? 0} '
            'deviceIdLen=${info['deviceId']?.length ?? 0}',
      );
      return;
    }

    final info = svc.getDeviceTokenInfo();
    final fcm = info['fcmToken']?.trim() ?? '';
    final deviceId = info['deviceId']?.trim() ?? '';
    if (fcm.isEmpty || deviceId.isEmpty) {
      fcmDiag(
        'API_REGISTER',
        'skip: empty fcm or deviceId (fcmEmpty=${fcm.isEmpty} '
            'deviceIdEmpty=${deviceId.isEmpty})',
      );
      return;
    }

    final platform = (info['deviceType'] == 'IOS') ? 'IOS' : 'ANDROID';

    try {
      fcmDiag(
        'API_REGISTER',
        'POST ${ApiEndpoints.notificationsRegisterDevice} '
            'platform=$platform devicePreview=${deviceId.length > 12 ? '${deviceId.substring(0, 12)}…' : deviceId} '
            'fcmPreview=${fcm.length > 24 ? '${fcm.substring(0, 24)}…' : fcm}',
      );
      final response = await DioClient.dio.post(
        ApiEndpoints.notificationsRegisterDevice,
        data: {
          'token': fcm,
          'platform': platform,
          'deviceId': deviceId,
          if (info['deviceName'] != null && info['deviceName']!.trim().isNotEmpty)
            'deviceName': info['deviceName'],
        },
      );
      fcmDiag(
        'API_REGISTER_OK',
        'HTTP ${response.statusCode} ${response.requestOptions.uri}',
      );

      // High-signal line for logcat: confirms backend stored FCM token for this session user.
      final uid = StorageService.getUserId();
      final role = StorageService.getUserRole();
      fcmDiag(
        'FCM_TOKEN_REGISTERED',
        'PushDevice upserted on API for userId=${uid ?? "?"} role=${role ?? "?"} '
            'platform=$platform firebaseConfigured→server will send pushes to this user',
      );
    } catch (e, st) {
      fcmDiag('API_REGISTER_FAIL', 'registration request failed', e, st);
    }
  }

  /// Best-effort unregister before logout (requires valid JWT).
  static Future<void> unregister() async {
    final token = StorageService.getToken();
    if (token == null || token.isEmpty) return;

    final deviceId = NotificationService().deviceId?.trim() ?? '';
    if (deviceId.isEmpty) return;

    try {
      await DioClient.dio.post(
        ApiEndpoints.notificationsRemoveDevice,
        data: {'deviceId': deviceId},
      );
    } catch (_) {
      // Ignore — logout must proceed
    }
  }
}
