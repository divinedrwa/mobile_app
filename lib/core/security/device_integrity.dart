import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Lightweight device integrity checks.
///
/// Shows a non-blocking warning dialog when the device appears to be
/// rooted (Android) or jailbroken (iOS). Payment apps typically warn
/// rather than block — users on rooted devices can dismiss and proceed.
///
/// Detection is best-effort: it checks common filesystem indicators
/// rather than pulling in a heavy native package. Sophisticated root
/// hiders will bypass these checks, but they catch the vast majority
/// of casual rooting.
class DeviceIntegrity {
  DeviceIntegrity._();

  static bool _checked = false;

  /// Call once from the app's first authenticated screen.
  /// Shows a warning dialog if the device appears compromised.
  static Future<void> checkOnce(BuildContext context) async {
    if (_checked || kDebugMode) return;
    _checked = true;

    final compromised = await _isDeviceCompromised();
    if (!compromised) return;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security Warning'),
        content: const Text(
          'This device appears to be rooted or jailbroken. '
          'Your data may be at risk. We recommend using a '
          'non-modified device for financial transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _isDeviceCompromised() async {
    try {
      if (Platform.isAndroid) return _checkAndroid();
      if (Platform.isIOS) return _checkIOS();
    } catch (_) {
      // Detection failure is not a security event — proceed normally.
    }
    return false;
  }

  static bool _checkAndroid() {
    const indicators = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/system/bin/failsafe/su',
      '/su/bin/su',
      '/system/app/SuperSU.apk',
      '/system/app/SuperSU',
      '/system/app/Magisk.apk',
    ];
    for (final path in indicators) {
      if (File(path).existsSync()) return true;
    }
    return false;
  }

  static bool _checkIOS() {
    const indicators = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
      '/private/var/lib/cydia',
      '/private/var/stash',
    ];
    for (final path in indicators) {
      if (File(path).existsSync()) return true;
      if (Directory(path).existsSync()) return true;
    }
    return false;
  }
}
