import 'package:flutter/foundation.dart';

import '../utils/platform_info.dart' as platform_info;
import 'in_app_update_wrapper.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';

enum UpdateStatus { upToDate, softUpdate, forceUpdate }

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
  /// Fail-open: any error returns [UpdateStatus.upToDate].
  static Future<VersionCheckResult> check() async {
    // 1. Try Play Store native check on Android.
    if (platform_info.isAndroid) {
      final playResult = await _checkPlayStore();
      if (playResult != null) return playResult;
    }

    // 2. Fallback: backend version config.
    return _checkBackend();
  }

  /// Start the native Play Store immediate update flow.
  ///
  /// On success Play may kill this process to install; the app is not
  /// auto-relaunched when the user updates from the Play Store listing
  /// (only the in-app immediate flow may restart in some cases).
  static Future<AppUpdateResult> performImmediateUpdate() async {
    return InAppUpdate.performImmediateUpdate();
  }

  /// Resume an immediate update that was interrupted (e.g. process killed
  /// mid-install). Safe to call on every cold start / resume.
  static Future<AppUpdateResult?> resumeInterruptedImmediateUpdate() async {
    if (!platform_info.isAndroid) return null;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final inProgress = info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress;
      if (!inProgress || !info.immediateUpdateAllowed) return null;
      return await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint(
        '[AppVersionService] Resume interrupted update failed (ignored): $e',
      );
      return null;
    }
  }

  /// Check Google Play Store for available updates via Play Core API.
  /// Returns null if no update available or Play Store check fails
  /// (e.g. sideloaded APK, Play Store not installed).
  static Future<VersionCheckResult?> _checkPlayStore() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      final updatePending = info.updateAvailability ==
              UpdateAvailability.updateAvailable ||
          info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress;

      if (updatePending) {
        // Immediate update = force (critical), flexible = soft prompt.
        // developerTriggeredUpdateInProgress = prior in-app immediate update
        // was interrupted; resume it instead of leaving the app stuck.
        if (info.immediateUpdateAllowed) {
          return VersionCheckResult(
            status: UpdateStatus.forceUpdate,
            playStoreUpdateInfo: info,
          );
        }
        if (info.flexibleUpdateAllowed) {
          return VersionCheckResult(
            status: UpdateStatus.softUpdate,
            playStoreUpdateInfo: info,
          );
        }
      }
      // No update or not allowed — let backend check decide.
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

      if (_compareSemver(installed, minVersion) < 0) {
        return VersionCheckResult(
          status: UpdateStatus.forceUpdate,
          latestVersion: latestVersion,
          minVersion: minVersion,
          storeUrl: storeUrl,
          releaseNotes: releaseNotes,
        );
      }

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
