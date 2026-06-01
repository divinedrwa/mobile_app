/// Web stubs for in_app_update (Android-only plugin).

class AppUpdateInfo {
  int get updateAvailability => 1; // UPDATE_NOT_AVAILABLE
  bool get immediateUpdateAllowed => false;
  bool get flexibleUpdateAllowed => false;
}

class UpdateAvailability {
  static const int updateAvailable = 2;
}

class InAppUpdate {
  static Future<AppUpdateInfo> checkForUpdate() async => AppUpdateInfo();
  static Future<void> performImmediateUpdate() async {}
}
