import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/storage_service.dart';

/// Types of guard mutations that can be queued offline.
enum OfflineMutationType {
  visitorCheckIn,
  vehicleEntry,
  patrolStart,
  patrolCheckpoint,
}

/// A single queued mutation, serializable to/from JSON.
@immutable
class OfflineMutation {
  const OfflineMutation({
    required this.id,
    required this.type,
    required this.params,
    required this.createdAt,
    this.retryCount = 0,
  });

  /// Unique id for deduplication.
  final String id;
  final OfflineMutationType type;
  final Map<String, dynamic> params;
  final DateTime createdAt;
  final int retryCount;

  /// Max retries before we drop the mutation.
  static const maxRetries = 5;

  /// Max age before we consider the mutation stale (24 hours).
  static const maxAge = Duration(hours: 24);

  bool get isStale => DateTime.now().difference(createdAt) > maxAge;
  bool get canRetry => retryCount < maxRetries && !isStale;

  OfflineMutation incrementRetry() => OfflineMutation(
        id: id,
        type: type,
        params: params,
        createdAt: createdAt,
        retryCount: retryCount + 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'params': params,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineMutation.fromJson(Map<String, dynamic> json) {
    return OfflineMutation(
      id: json['id'] as String,
      type: OfflineMutationType.values.byName(json['type'] as String),
      params: Map<String, dynamic>.from(json['params'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

/// Persistence layer for the guard offline mutation queue.
///
/// Stores a JSON-encoded list in SharedPreferences. The queue is append-only
/// from the guard screens; the sync notifier reads + removes entries as they
/// succeed or expire.
class OfflineQueueService {
  static const _key = 'guard_offline_queue';

  /// Read all queued mutations.
  static List<OfflineMutation> getAll() {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(OfflineMutation.fromJson).toList();
    } catch (e) {
      debugPrint('[OfflineQueue] corrupt queue data, clearing: $e');
      StorageService.remove(_key);
      return [];
    }
  }

  /// Append a mutation to the queue.
  static Future<void> enqueue(OfflineMutation mutation) async {
    final list = getAll();
    // Dedup by id.
    list.removeWhere((m) => m.id == mutation.id);
    list.add(mutation);
    await _persist(list);
  }

  /// Remove a mutation by id (after successful sync).
  static Future<void> remove(String id) async {
    final list = getAll();
    list.removeWhere((m) => m.id == id);
    await _persist(list);
  }

  /// Update a mutation (e.g. increment retry count).
  static Future<void> update(OfflineMutation mutation) async {
    final list = getAll();
    final idx = list.indexWhere((m) => m.id == mutation.id);
    if (idx >= 0) {
      list[idx] = mutation;
    }
    await _persist(list);
  }

  /// Remove stale and exhausted entries.
  static Future<int> purgeExpired() async {
    final list = getAll();
    final before = list.length;
    list.removeWhere((m) => !m.canRetry);
    if (list.length != before) await _persist(list);
    return before - list.length;
  }

  /// Clear the entire queue.
  static Future<void> clearAll() async {
    await StorageService.remove(_key);
  }

  static Future<void> _persist(List<OfflineMutation> list) async {
    final encoded = json.encode(list.map((m) => m.toJson()).toList());
    await StorageService.setString(_key, encoded);
  }
}
