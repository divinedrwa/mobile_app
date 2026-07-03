import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';
import '../utils/platform_info.dart' as platform_info;
import 'in_app_update_wrapper.dart';

enum UpdateStatus { upToDate, softUpdate }

class VersionCheckResult {
  final UpdateStatus status;

  /// Non-null when Google Play reports an available update (Android only).
  final AppUpdateInfo? playStoreUpdateInfo;

  /// Backend-configured values (iOS path only).
  final String? latestVersion;
  final String? storeUrl;
  final String? releaseNotes;

  const VersionCheckResult({
    required this.status,
    this.playStoreUpdateInfo,
    this.latestVersion,
    this.storeUrl,
    this.releaseNotes,
  });

  static const upToDate = VersionCheckResult(status: UpdateStatus.upToDate);

  /// Stable id for the available update, used to remember a "Later" dismissal.
  /// Play version code on Android; configured version string on iOS.
  String? get availableVersionKey =>
      playStoreUpdateInfo?.availableVersionCode?.toString() ?? latestVersion;
}

/// App update check.
///
/// - **Android** → Google Play in-app update (`in_app_update`). Play decides
///   whether the installed build is behind the store.
/// - **iOS** → backend version config (`/public/app-version?platform=IOS`),
///   since Apple has no in-app update API — we can only nudge to the App Store.
///
/// Updates are **never forced**: only [UpdateStatus.upToDate] or a dismissible
/// [UpdateStatus.softUpdate]. Fail-open on any error.
class AppVersionService {
  static Future<VersionCheckResult> check() async {
    if (platform_info.isAndroid) return _checkPlayStore();
    if (platform_info.isIOS) return _checkBackend();
    return VersionCheckResult.upToDate;
  }

  static Future<VersionCheckResult> _checkPlayStore() async {
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

  /// iOS: compare the installed version against the backend's configured
  /// `latestVersion`. `minVersion` is intentionally ignored (never force).
  static Future<VersionCheckResult> _checkBackend() async {
    try {
      final response = await DioClient.dio.get(
        ApiEndpoints.appVersionCheck,
        queryParameters: {'platform': 'IOS'},
      );
      final config = response.data?['config'];
      if (config == null) return VersionCheckResult.upToDate;

      final latestVersion = config['latestVersion'] as String?;
      final storeUrl = config['storeUrl'] as String?;
      final releaseNotes = config['releaseNotes'] as String?;
      if (latestVersion == null) return VersionCheckResult.upToDate;

      final installed = (await PackageInfo.fromPlatform()).version;
      if (_compareSemver(installed, latestVersion) < 0) {
        return VersionCheckResult(
          status: UpdateStatus.softUpdate,
          latestVersion: latestVersion,
          storeUrl: storeUrl,
          releaseNotes: releaseNotes,
        );
      }
      return VersionCheckResult.upToDate;
    } catch (e) {
      debugPrint('[AppVersionService] iOS version check failed (fail-open): $e');
      return VersionCheckResult.upToDate;
    }
  }

  /// Compare two semver strings. Returns -1, 0, or 1.
  static int _compareSemver(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? pa[i] : 0;
      final nb = i < pb.length ? pb[i] : 0;
      if (na < nb) return -1;
      if (na > nb) return 1;
    }
    return 0;
  }

  /// Run Google Play's **flexible** in-app update (Android): consent sheet,
  /// background download, then install. The user can decline — nothing forced.
  ///
  /// Returns true when handled in-app (started + completed, or user declined);
  /// false when unavailable so the caller can fall back to the store listing.
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
