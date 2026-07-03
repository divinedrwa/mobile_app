import 'package:flutter/foundation.dart';

import '../utils/platform_info.dart' as platform_info;
import 'in_app_update_wrapper.dart';

enum UpdateStatus { upToDate, softUpdate }

class VersionCheckResult {
  final UpdateStatus status;

  /// Non-null when Google Play reports an available update (Android only).
  final AppUpdateInfo? playStoreUpdateInfo;

  const VersionCheckResult({
    required this.status,
    this.playStoreUpdateInfo,
  });

  static const upToDate = VersionCheckResult(status: UpdateStatus.upToDate);

  /// Stable id for the available update (Play version code) — used to remember
  /// a "Later" dismissal so the same version isn't prompted again.
  String? get availableVersionKey =>
      playStoreUpdateInfo?.availableVersionCode?.toString();
}

/// Thin wrapper over Google Play's in-app update API (`in_app_update`).
///
/// Play itself decides whether the installed build is behind the store — we
/// don't compare versions ourselves. Updates are **never forced**: the only
/// outcomes are [UpdateStatus.upToDate] or a dismissible
/// [UpdateStatus.softUpdate]. Android only; iOS / non-Play (sideloaded) installs
/// always report up to date.
class AppVersionService {
  static Future<VersionCheckResult> check() async {
    if (!platform_info.isAndroid) return VersionCheckResult.upToDate;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        return VersionCheckResult(
          status: UpdateStatus.softUpdate,
          playStoreUpdateInfo: info,
        );
      }
      return VersionCheckResult.upToDate;
    } catch (e) {
      // Sideloaded builds throw ERROR_APP_NOT_OWNED; any failure = up to date.
      debugPrint('[AppVersionService] Play update check failed: $e');
      return VersionCheckResult.upToDate;
    }
  }

  /// Run Google Play's **flexible** in-app update: shows Play's consent sheet,
  /// downloads in the background, then installs it. The user can decline —
  /// nothing is forced.
  ///
  /// Returns true when handled in-app (started + completed, or user declined);
  /// false when a flexible update isn't available so the caller can fall back
  /// to opening the store listing.
  static Future<bool> startFlexibleInAppUpdate() async {
    if (!platform_info.isAndroid) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.flexibleUpdateAllowed) {
        return false;
      }
      final result = await InAppUpdate.startFlexibleUpdate();
      switch (result) {
        case AppUpdateResult.success:
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        case AppUpdateResult.userDeniedUpdate:
          return true;
        case AppUpdateResult.inAppUpdateFailed:
          return false;
      }
    } catch (e) {
      debugPrint('[AppVersionService] Flexible in-app update failed: $e');
      return false;
    }
  }
}
