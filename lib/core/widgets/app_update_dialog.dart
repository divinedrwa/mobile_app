import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';
import '../utils/play_store_launch.dart';

const _dismissedVersionKey = 'dismissed_update_version';

/// Show the dismissible "Update Available" prompt.
///
/// Updates are always optional: "Later" lets the user keep using their current
/// version (persisted so we don't nag again for the same version). "Update"
/// runs Play's flexible in-app update on Android (background download +
/// install), falling back to opening the store listing.
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

/// "Update" pressed — try Play's flexible in-app update first (Android), then
/// fall back to opening the store listing.
Future<void> _handleUpdate(VersionCheckResult result) async {
  if (result.playStoreUpdateInfo != null) {
    final handled = await AppVersionService.startFlexibleInAppUpdate();
    if (handled) return;
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
  await openPlayStoreListing();
}
