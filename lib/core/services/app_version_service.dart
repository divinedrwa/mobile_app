import 'package:flutter/foundation.dart';

import '../utils/platform_info.dart' as platform_info;
import 'in_app_update_wrapper.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';

enum UpdateStatus { upToDate, softUpdate }

class VersionCheckResult {
  final UpdateStatus status;
  final String? latestVersion;
  final String? minVersion;
  final String? storeUrl;
  final String? releaseNotes;

  /// Non-null when Play Store native update is available (Android only).
  final AppUpdateInfo? playStoreUpdateInfo;

  const VersionCheckResult({
    required this.status,
    this.latestVersion,
    this.minVersion,
    this.storeUrl,
    this.releaseNotes,
    this.playStoreUpdateInfo,
  });

  static const upToDate = VersionCheckResult(status: UpdateStatus.upToDate);
}

class AppVersionService {
  /// Primary check flow:
  /// 1. Android → try Play Store native update (Play Core API).
  /// 2. Fallback → backend version config check (works on all platforms).
  ///
  /// Updates are **never forced** — the app must stay fully usable on any
  /// version, old or new. The only outcome besides [UpdateStatus.upToDate] is
  /// a dismissible [UpdateStatus.softUpdate] prompt when a newer version is
  /// available. Fail-open: any error returns [UpdateStatus.upToDate].
  static Future<VersionCheckResult> check() async {
    // 1. Try Play Store native check on Android.
    if (platform_info.isAndroid) {
      final playResult = await _checkPlayStore();
      if (playResult != null) return playResult;
    }

    // 2. Fallback: backend version config.
    return _checkBackend();
  }

  /// Run Google Play's **flexible** in-app update: shows Play's consent sheet,
  /// downloads the update in the background, then installs it (Play restarts
  /// the app to apply). The user can decline at any point — nothing is forced.
  ///
  /// Returns true when the update was handled in-app (started + completed, or
  /// the user explicitly declined); false when a flexible update isn't
  /// available (sideloaded build, Play Store missing, transient failure) so
  /// the caller can fall back to opening the store listing.
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
          // Downloaded in the background — install it now.
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        case AppUpdateResult.userDeniedUpdate:
          // User chose to keep their current version — respect it.
          return true;
        case AppUpdateResult.inAppUpdateFailed:
          return false;
      }
    } catch (e) {
      debugPrint('[AppVersionService] Flexible in-app update failed: $e');
      return false;
    }
  }

  /// Check Google Play Store for available updates via Play Core API.
  /// Returns null if no update available or Play Store check fails
  /// (e.g. sideloaded APK, Play Store not installed).
  static Future<VersionCheckResult?> _checkPlayStore() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      final updatePending = info.updateAvailability ==
          UpdateAvailability.updateAvailable;

      if (updatePending) {
        // A newer version is on the Play Store — offer a dismissible soft
        // prompt only. We never force (no immediate flow), so the app stays
        // usable whether the user updates now or later.
        return VersionCheckResult(
          status: UpdateStatus.softUpdate,
          playStoreUpdateInfo: info,
        );
      }
      // No update available — let backend check decide.
      return null;
    } catch (e) {
      debugPrint('[AppVersionService] Play Store check failed (falling back to backend): $e');
      return null;
    }
  }

  /// Check backend API for version config and compare against installed version.
  static Future<VersionCheckResult> _checkBackend() async {
    try {
      final String platform;
      if (platform_info.isAndroid) {
        platform = 'ANDROID';
      } else if (platform_info.isIOS) {
        platform = 'IOS';
      } else {
        return VersionCheckResult.upToDate;
      }

      final response = await DioClient.dio.get(
        ApiEndpoints.appVersionCheck,
        queryParameters: {'platform': platform},
      );

      final config = response.data?['config'];
      if (config == null) return VersionCheckResult.upToDate;

      final latestVersion = config['latestVersion'] as String?;
      final minVersion = config['minVersion'] as String?;
      final storeUrl = config['storeUrl'] as String?;
      final releaseNotes = config['releaseNotes'] as String?;

      if (latestVersion == null || minVersion == null) {
        return VersionCheckResult.upToDate;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final installed = packageInfo.version;

      // Never force: `minVersion` is intentionally ignored so the app stays
      // usable on any version. Only show a dismissible soft prompt when a
      // newer version has been published.
      if (_compareSemver(installed, latestVersion) < 0) {
        return VersionCheckResult(
          status: UpdateStatus.softUpdate,
          latestVersion: latestVersion,
          minVersion: minVersion,
          storeUrl: storeUrl,
          releaseNotes: releaseNotes,
        );
      }

      return VersionCheckResult.upToDate;
    } catch (e) {
      debugPrint('[AppVersionService] Backend check failed (fail-open): $e');
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
}
