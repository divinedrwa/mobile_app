import 'dart:convert';

import '../../core/utils/storage_service.dart';

/// Tiny persistent stale-while-revalidate cache for raw API JSON, mirroring
/// [SocietyThemeCache] (which uses [StorageService.getString]/[setString] with
/// [jsonEncode]/[jsonDecode] and corrupt-safe decoding).
///
/// Only plain JSON should be written here (the raw maps/lists returned by the
/// API). Every decode is wrapped in a try/catch that returns `null` on any
/// error, so a schema change or a corrupt entry can never crash the app — the
/// caller silently falls through to the network path.
class PersistentListCache {
  PersistentListCache._();

  /// Serializes [jsonEncodable] and stores it under [key]. Any encode failure
  /// is swallowed — a cache write must never surface an error to callers.
  static Future<void> write(String key, Object? jsonEncodable) async {
    try {
      await StorageService.setString(key, jsonEncode(jsonEncodable));
    } catch (_) {
      // Non-encodable payload — skip caching rather than throw.
    }
  }

  /// Reads and decodes the entry at [key], mapping the raw decoded JSON through
  /// [decode]. Returns `null` when the entry is missing, corrupt, or [decode]
  /// throws (e.g. after a model/schema change).
  static T? read<T>(String key, T Function(dynamic json) decode) {
    try {
      final raw = StorageService.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return decode(jsonDecode(raw));
    } catch (_) {
      // Corrupt/schema-incompatible entry, or storage not initialized.
      return null;
    }
  }

  /// Removes the cached entry at [key].
  static Future<void> clear(String key) => StorageService.remove(key);

  /// Society id used for cache scoping — mirrors
  /// [SocietyThemeCache.activeSocietyId] (logged-in society, else last picked).
  static String? _societyId() {
    final sid = StorageService.getSocietyId()?.trim() ??
        StorageService.getPreferredLoginSocietyId()?.trim();
    if (sid == null || sid.isEmpty) return null;
    return sid;
  }

  /// Builds a cache key scoped by the active society + user, so a shared device
  /// (or a re-login as a different resident) never reads another account's list.
  /// Returns `null` when there is no society/user context yet (or if storage is
  /// not initialized) — callers should skip caching in that case.
  static String? scopedKey(String name) {
    try {
      final sid = _societyId();
      final uid = StorageService.getUserId()?.trim();
      if (sid == null || uid == null || uid.isEmpty) return null;
      return 'list_cache_v1_${name}_${sid}_$uid';
    } catch (_) {
      // StorageService not initialized (e.g. unit tests) — no scoped cache.
      return null;
    }
  }
}
