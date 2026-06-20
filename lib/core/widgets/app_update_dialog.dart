import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';
import '../services/in_app_update_wrapper.dart';
import '../utils/play_store_launch.dart';

const _dismissedVersionKey = 'dismissed_update_version';

/// Show the in-app update dialog.
///
/// If the result came from Play Store native check ([playStoreUpdateInfo] != null),
/// the "Update" button triggers the native Play Store update flow.
/// Otherwise it opens the store listing.
///
/// [forceUpdate] = true  → non-dismissible, no "Later" button.
/// [forceUpdate] = false → dismissible with "Later" (persists dismissed version).
Future<void> showAppUpdateDialog(
  BuildContext context,
  VersionCheckResult result, {
  required bool forceUpdate,
}) {
  // Play Store native immediate update — takes over the screen, no dialog needed.
  if (forceUpdate && result.playStoreUpdateInfo != null) {
    return _tryNativeImmediateUpdate(context, result);
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (ctx) => PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        title: Text(forceUpdate ? 'Update Required' : 'Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              forceUpdate
                  ? 'A required update is available. Please update to continue using the app.'
                  : result.latestVersion != null
                      ? 'A new version (${result.latestVersion}) is available.'
                      : 'A new version is available.',
            ),
            if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "What's new:",
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                result.releaseNotes!,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () async {
                if (result.latestVersion != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_dismissedVersionKey, result.latestVersion!);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () => _handleUpdate(result),
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
}

/// Returns true if the user has already dismissed this version's soft-update prompt.
Future<bool> wasSoftUpdateDismissed(String version) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_dismissedVersionKey) == version;
}

/// Try native Play Store immediate update; fall back to store listing on failure.
///
/// Play may terminate this process to install. That is expected — it is not a
/// crash. Play Store listing updates do not auto-open the app when finished;
/// the user taps Open or the launcher icon.
Future<void> _tryNativeImmediateUpdate(
  BuildContext context,
  VersionCheckResult result,
) async {
  try {
    final updateResult = await AppVersionService.performImmediateUpdate();
    switch (updateResult) {
      case AppUpdateResult.success:
        // Play installs in the background or restarts the process.
        return;
      case AppUpdateResult.userDeniedUpdate:
      case AppUpdateResult.inAppUpdateFailed:
        debugPrint(
          '[AppUpdateDialog] Immediate update ended: $updateResult',
        );
        if (!context.mounted) return;
        await _showPlayStoreFallbackDialog(context, result);
    }
  } catch (e) {
    debugPrint('[AppUpdateDialog] Native immediate update failed: $e');
    if (context.mounted) {
      await _showPlayStoreFallbackDialog(context, result);
    }
  }
}

Future<void> _showPlayStoreFallbackDialog(
  BuildContext context,
  VersionCheckResult result,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Update Required'),
        content: const Text(
          'A required update is available. Please update from the Play Store to continue.',
        ),
        actions: [
          FilledButton(
            onPressed: () => _openStore(result.storeUrl),
            child: const Text('Open Play Store'),
          ),
        ],
      ),
    ),
  );
}

/// Handle the "Update" button press — always opens the store listing.
/// Native flexible update is unreliable (download must finish before install),
/// so we skip it and send the user straight to the store.
Future<void> _handleUpdate(VersionCheckResult result) async {
  await _openStore(result.storeUrl);
}

Future<void> _openStore(String? customUrl) async {
  if (customUrl != null && customUrl.isNotEmpty) {
    final uri = Uri.tryParse(customUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }
  await openPlayStoreListing();
}
