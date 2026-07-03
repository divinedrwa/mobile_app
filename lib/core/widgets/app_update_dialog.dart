import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_version_service.dart';
import '../utils/play_store_launch.dart';

const _dismissedVersionKey = 'dismissed_update_version';

/// Show the dismissible "Update Available" prompt (Google Play).
///
/// Updates are always optional: "Later" lets the user keep their current
/// version (remembered so we don't nag again for the same version). "Update"
/// runs Play's flexible in-app update (background download + install), falling
/// back to opening the store listing.
Future<void> showAppUpdateDialog(
  BuildContext context,
  VersionCheckResult result,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Update Available'),
      content: const Text(
        'A new version of the app is available. Update now for the latest '
        'features and fixes.',
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

/// "Update" pressed — try Play's flexible in-app update, then fall back to the
/// store listing.
Future<void> _handleUpdate(VersionCheckResult result) async {
  final handled = await AppVersionService.startFlexibleInAppUpdate();
  if (handled) return;
  await openPlayStoreListing();
}
