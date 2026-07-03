import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';
import '../utils/play_store_launch.dart';

const _dismissedVersionKey = 'dismissed_update_version';

/// Show the dismissible "Update Available" prompt.
///
/// Updates are always optional: "Later" keeps the current version (remembered
/// so we don't nag again). "Update" runs Play's flexible in-app update on
/// Android; on iOS it opens the App Store listing (Apple has no in-app update).
Future<void> showAppUpdateDialog(
  BuildContext context,
  VersionCheckResult result,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.latestVersion != null
                ? 'A new version (${result.latestVersion}) is available.'
                : 'A new version of the app is available.',
          ),
          if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text("What's new:", style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(result.releaseNotes!, style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final key = result.availableVersionKey;
            if (key != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_dismissedVersionKey, key);
            }
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _handleUpdate(result);
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}

/// Returns true if the user has already dismissed this version's soft-update prompt.
Future<bool> wasSoftUpdateDismissed(String version) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_dismissedVersionKey) == version;
}

/// "Update" pressed. Android → Play flexible in-app update (fallback to store).
/// iOS → open the App Store listing (custom URL if configured, else the app page).
Future<void> _handleUpdate(VersionCheckResult result) async {
  if (result.playStoreUpdateInfo != null) {
    final handled = await AppVersionService.startFlexibleInAppUpdate();
    if (handled) return;
    await openPlayStoreListing();
    return;
  }
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
  // Platform-correct fallback: App Store on iOS, Play Store on Android.
  await openPlayStoreListing();
}
