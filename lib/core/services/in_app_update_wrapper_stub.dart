enum AppUpdateResult {
  success,
  userDeniedUpdate,
  inAppUpdateFailed,
}

/// Web stubs for in_app_update (Android-only plugin).

class AppUpdateInfo {
  UpdateAvailability get updateAvailability => UpdateAvailability.updateNotAvailable;
  bool get immediateUpdateAllowed => false;
  bool get flexibleUpdateAllowed => false;
  int? get availableVersionCode => null;
}

class UpdateAvailability {
  static const updateNotAvailable = UpdateAvailability._(1);
  static const updateAvailable = UpdateAvailability._(2);
  static const developerTriggeredUpdateInProgress = UpdateAvailability._(3);

  const UpdateAvailability._(this.value);
  final int value;
}

class InAppUpdate {
  static Future<AppUpdateInfo> checkForUpdate() async => AppUpdateInfo();
  static Future<AppUpdateResult> performImmediateUpdate() async =>
      AppUpdateResult.success;
  static Future<AppUpdateResult> startFlexibleUpdate() async =>
      AppUpdateResult.inAppUpdateFailed;
  static Future<void> completeFlexibleUpdate() async {}
}
