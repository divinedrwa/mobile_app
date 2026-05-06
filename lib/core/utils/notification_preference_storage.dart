import '../constants/app_constants.dart';
import 'storage_service.dart';

/// Persisted on-device notification preferences (master + push).
/// Email preference is stored on the server as [UserModel.notifyEmail].
class NotificationPreferenceStorage {
  NotificationPreferenceStorage._();

  static bool get notificationsEnabled =>
      StorageService.getBool(AppConstants.keyNotificationsEnabled) ?? true;

  static bool get pushNotificationsEnabled =>
      StorageService.getBool(AppConstants.keyPushNotificationsEnabled) ?? true;

  /// Whether remote pushes should be registered and foreground banners shown.
  static bool get shouldDeliverPush =>
      notificationsEnabled && pushNotificationsEnabled;

  static Future<void> setNotificationsEnabled(bool value) =>
      StorageService.setBool(AppConstants.keyNotificationsEnabled, value);

  static Future<void> setPushNotificationsEnabled(bool value) =>
      StorageService.setBool(AppConstants.keyPushNotificationsEnabled, value);
}
