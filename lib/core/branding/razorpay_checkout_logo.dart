import 'dart:convert';

import 'package:flutter/services.dart';

/// Bundled GatePass+ icon — kept in sync with iOS `ItunesArtwork@2x.png`.
const kRazorpayCheckoutLogoAsset = 'assets/branding/app_icon.png';

String? _cachedCheckoutLogoDataUri;

/// Razorpay accepts HTTPS URLs or `data:image/png;base64,...` for checkout logo.
Future<String?> loadRazorpayCheckoutLogoDataUri() async {
  final cached = _cachedCheckoutLogoDataUri;
  if (cached != null) return cached;
  try {
    final bytes = await rootBundle.load(kRazorpayCheckoutLogoAsset);
    final b64 = base64Encode(bytes.buffer.asUint8List());
    _cachedCheckoutLogoDataUri = 'data:image/png;base64,$b64';
    return _cachedCheckoutLogoDataUri;
  } catch (_) {
    return null;
  }
}

/// API-hosted logo (also synced from the same source icon in `backend/brand-assets/`).
String razorpayCheckoutLogoUrl(String apiBaseUrl) {
  final origin = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$origin/brand/app-logo.png';
}

/// Prefer bundled icon; fall back to API `/brand/app-logo.png` when asset load fails.
Future<String> resolveRazorpayCheckoutLogo(String apiBaseUrl) async {
  return await loadRazorpayCheckoutLogoDataUri() ??
      razorpayCheckoutLogoUrl(apiBaseUrl);
}
