import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Opens the correct store for the platform: **Google Play** on Android, **App Store** on iOS.
Future<bool> openPlayStoreListing() async {
  final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  if (ios) {
    return _openIosAppStore();
  }
  return _openAndroidPlayStore();
}

Future<bool> _openIosAppStore() async {
  final id = AppConstants.iosAppStoreId.trim();
  final https = id.isEmpty
      ? Uri.parse('https://apps.apple.com')
      : Uri.parse('https://apps.apple.com/app/id$id');
  final itms = id.isEmpty
      ? Uri.parse('itms-apps://apps.apple.com')
      : Uri.parse('itms-apps://itunes.apple.com/app/id$id');
  if (await canLaunchUrl(itms)) {
    return launchUrl(itms, mode: LaunchMode.externalApplication);
  }
  return launchUrl(https, mode: LaunchMode.externalApplication);
}

Future<bool> _openAndroidPlayStore() async {
  final package = AppConstants.androidApplicationId;
  final market = Uri.parse('market://details?id=$package');
  final https = Uri.parse(
    'https://play.google.com/store/apps/details?id=$package',
  );
  if (await canLaunchUrl(market)) {
    return launchUrl(market, mode: LaunchMode.externalApplication);
  }
  return launchUrl(https, mode: LaunchMode.externalApplication);
}
