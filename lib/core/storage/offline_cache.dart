import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight offline cache backed by SharedPreferences.
///
/// Stores JSON-serializable data with a TTL. When the network request
/// fails, callers can fall back to [get] which returns cached data if
/// it hasn't expired.
///
/// Usage:
/// ```dart
/// final cache = OfflineCache();
/// // After a successful fetch:
/// await cache.put('maintenance_pending', jsonData, ttl: Duration(minutes: 30));
/// // On network error:
/// final cached = await cache.get<List>('maintenance_pending');
/// if (cached != null) { /* use stale data */ }
/// ```
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  static const _prefix = 'offline_cache_';
  static const _tsPrefix = 'offline_cache_ts_';
  static const _ttlPrefix = 'offline_cache_ttl_';

  /// Store [data] under [key] with an optional [ttl] (default 30 minutes).
  /// [data] must be JSON-encodable (Map, List, String, num, bool, null).
  Future<void> put(
    String key,
    dynamic data, {
    Duration ttl = const Duration(minutes: 30),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(data);
      await prefs.setString('$_prefix$key', json);
      await prefs.setInt('$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('$_ttlPrefix$key', ttl.inMilliseconds);
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineCache] put($key) failed: $e');
    }
  }

  /// Retrieve cached data for [key]. Returns `null` if not cached or expired.
  /// If [ignoreExpiry] is true, returns data even if TTL has passed (useful
  /// for showing stale data with a freshness indicator).
  Future<T?> get<T>(String key, {bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_prefix$key');
      if (json == null) return null;

      if (!ignoreExpiry) {
        final ts = prefs.getInt('$_tsPrefix$key') ?? 0;
        final ttlMs = prefs.getInt('$_ttlPrefix$key') ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age > ttlMs) return null;
      }

      return jsonDecode(json) as T?;
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineCache] get($key) failed: $e');
      return null;
    }
  }

  /// Check whether the cache entry is stale (past TTL but still present).
  Future<bool> isStale(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_prefix$key');
      if (json == null) return false;

      final ts = prefs.getInt('$_tsPrefix$key') ?? 0;
      final ttlMs = prefs.getInt('$_ttlPrefix$key') ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age > ttlMs;
    } catch (_) {
      return false;
    }
  }

  /// Remove a specific cached entry.
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
      await prefs.remove('$_tsPrefix$key');
      await prefs.remove('$_ttlPrefix$key');
    } catch (_) {}
  }

  /// Clear all offline cache entries.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix) || k.startsWith(_ttlPrefix),
      );
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
