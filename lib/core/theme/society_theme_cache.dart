import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../utils/image_url.dart';
import '../utils/storage_service.dart';
import 'app_colors_bridge.dart';
import '../../theme/app_colors.dart';

/// Persists society appearance (theme JSON + splash URL) keyed by [societyId]
/// so the app can paint the correct palette on the first frame before any
/// network round-trip.
class SocietyThemeCache {
  SocietyThemeCache._();

  /// Set in [seedBridgeFromStorage] before [runApp]; read by [ThemeTokensNotifier]
  /// so the first ProviderScope frame matches the bootstrap bridge (no green flash).
  static AppColorPalette? _bootstrapPalette;

  static AppColorPalette? peekBootstrapPalette() => _bootstrapPalette;

  static String _themeKey(String societyId) =>
      AppConstants.societyThemeCacheKey(societyId);

  static String _splashKey(String societyId) =>
      AppConstants.societySplashCacheKey(societyId);

  /// Society id used for startup palette resolution (logged-in or last picked).
  static String? activeSocietyId() {
    final sid = StorageService.getSocietyId()?.trim() ??
        StorageService.getPreferredLoginSocietyId()?.trim();
    if (sid == null || sid.isEmpty) return null;
    return sid;
  }

  static Map<String, dynamic>? readThemeJson(String societyId) {
    final sid = societyId.trim();
    if (sid.isEmpty) return null;

    final scoped = StorageService.getString(_themeKey(sid));
    if (scoped != null && scoped.isNotEmpty) {
      return _decodeThemeJson(scoped);
    }

    // Legacy global key — migrate on read when it matches the active society.
    if (sid == activeSocietyId()) {
      final legacy = StorageService.getString(AppConstants.keyCachedSocietyTheme);
      if (legacy != null && legacy.isNotEmpty) {
        final decoded = _decodeThemeJson(legacy);
        if (decoded != null) {
          writeThemeJson(sid, decoded);
        }
        return decoded;
      }
    }
    return null;
  }

  static String? readSplashUrl(String societyId) {
    final sid = societyId.trim();
    if (sid.isEmpty) return null;

    final scoped = StorageService.getString(_splashKey(sid));
    if (scoped != null && scoped.isNotEmpty) return scoped;

    if (sid == activeSocietyId()) {
      final legacy = StorageService.getString(AppConstants.keyCachedSplashUrl);
      if (legacy != null && legacy.isNotEmpty) {
        writeSplashUrl(sid, legacy);
        return legacy;
      }
    }
    return null;
  }

  static String _splashFilePathKey(String societyId) =>
      AppConstants.societySplashFileCacheKey(societyId);

  /// Absolute path to the on-disk splash JPEG for [societyId], if present.
  static String? readSplashFilePath(String societyId) {
    final sid = societyId.trim();
    if (sid.isEmpty) return null;
    final path = StorageService.getString(_splashFilePathKey(sid));
    if (path == null || path.isEmpty) return null;
    if (!File(path).existsSync()) return null;
    return path;
  }

  static bool hasSplashFile(String societyId) =>
      readSplashFilePath(societyId) != null;

  /// Download (or skip if URL unchanged) and persist splash bytes locally so
  /// the next launch paints the society splash on the first frame — no bundled
  /// asset flash while [CachedNetworkImage] loads from the network.
  static Future<void> ensureSplashFile(String societyId, String url) async {
    final sid = societyId.trim();
    final trimmedUrl = url.trim();
    if (sid.isEmpty || trimmedUrl.isEmpty) return;

    final cachedUrl = readSplashUrl(sid);
    if (cachedUrl == trimmedUrl && hasSplashFile(sid)) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/society_splash');
      if (!folder.existsSync()) {
        await folder.create(recursive: true);
      }
      final file = File('${folder.path}/$sid.jpg');
      final optimized = optimizedCloudinaryUrl(trimmedUrl, width: 1080);
      final response = await Dio().get<List<int>>(
        optimized,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return;
      await file.writeAsBytes(bytes, flush: true);
      await writeSplashUrl(sid, trimmedUrl);
      await StorageService.setString(_splashFilePathKey(sid), file.path);
    } catch (_) {
      // Keep any previously cached file.
    }
  }

  static Future<void> clearSplashFile(String societyId) async {
    final sid = societyId.trim();
    if (sid.isEmpty) return;
    final path = StorageService.getString(_splashFilePathKey(sid));
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }
    await StorageService.setString(_splashFilePathKey(sid), '');
    await writeSplashUrl(sid, null);
  }

  static AppColorPalette? readPalette(String societyId) {
    final json = readThemeJson(societyId);
    if (json == null || json.isEmpty) return null;
    return AppColorPalette.fromApiJson(json, AppColorPalette.light);
  }

  static Future<void> writeThemeJson(
    String societyId,
    Map<String, dynamic> themeJson,
  ) async {
    final sid = societyId.trim();
    if (sid.isEmpty) return;
    final encoded = jsonEncode(themeJson);
    await StorageService.setString(_themeKey(sid), encoded);
    // Keep legacy key in sync for older builds / debugging.
    if (sid == activeSocietyId()) {
      await StorageService.setString(AppConstants.keyCachedSocietyTheme, encoded);
    }
  }

  static Future<void> writeSplashUrl(String societyId, String? url) async {
    final sid = societyId.trim();
    if (sid.isEmpty) return;
    final value = url?.trim() ?? '';
    await StorageService.setString(_splashKey(sid), value);
    if (sid == activeSocietyId()) {
      await StorageService.setString(AppConstants.keyCachedSplashUrl, value);
    }
  }

  static Future<void> clearTheme(String societyId) async {
    final sid = societyId.trim();
    if (sid.isEmpty) return;
    await StorageService.setString(_themeKey(sid), '');
    if (sid == activeSocietyId()) {
      await StorageService.setString(AppConstants.keyCachedSocietyTheme, '');
    }
  }

  static bool themeJsonEquals(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return jsonEncode(a) == jsonEncode(b);
  }

  static Map<String, dynamic>? _decodeThemeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Corrupt cache entry.
    }
    return null;
  }

  /// Call once after [StorageService.init] — before [runApp] — so the first
  /// Flutter frame uses the cached society palette instead of compile-time green.
  static void seedBridgeFromStorage() {
    final sid = activeSocietyId();
    if (sid == null) return;
    final palette = readPalette(sid);
    if (palette != null) {
      _bootstrapPalette = palette;
      AppColorBridge.applyPalette(palette);
    }
  }
}
