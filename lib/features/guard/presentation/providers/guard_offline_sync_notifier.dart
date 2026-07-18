import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/connectivity_provider.dart';
import '../../data/offline_queue_service.dart';
import '../../data/repositories/guard_repository.dart';
import 'guard_providers.dart';

/// State exposed to the UI — just pending count + last sync status.
@immutable
class OfflineSyncState {
  const OfflineSyncState({
    this.pendingCount = 0,
    this.syncing = false,
    this.lastSyncMessage,
  });

  final int pendingCount;
  final bool syncing;
  final String? lastSyncMessage;

  OfflineSyncState copyWith({
    int? pendingCount,
    bool? syncing,
    String? lastSyncMessage,
    bool clearMessage = false,
  }) {
    return OfflineSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      syncing: syncing ?? this.syncing,
      lastSyncMessage:
          clearMessage ? null : (lastSyncMessage ?? this.lastSyncMessage),
    );
  }
}

/// Watches connectivity and replays queued guard mutations when back online.
class OfflineSyncNotifier extends StateNotifier<OfflineSyncState> {
  OfflineSyncNotifier(this._ref) : super(const OfflineSyncState()) {
    // Read initial queue size.
    _refreshCount();

    // Watch connectivity changes.
    _sub = _ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final wasOffline = prev?.valueOrNull != true;
      final isOnline = next.valueOrNull == true;
      if (wasOffline && isOnline && state.pendingCount > 0) {
        syncAll();
      }
    });
  }

  final Ref _ref;
  ProviderSubscription<AsyncValue<bool>>? _sub;

  void _refreshCount() {
    final count = OfflineQueueService.getAll().length;
    state = state.copyWith(pendingCount: count);
  }

  /// Enqueue a mutation for later sync. Called when the device is offline
  /// and a guard tries to perform a critical action.
  Future<void> enqueue(OfflineMutation mutation) async {
    await OfflineQueueService.enqueue(mutation);
    _refreshCount();
  }

  /// Try to sync all pending mutations. Called automatically when
  /// connectivity is restored, or manually by the user.
  Future<void> syncAll() async {
    if (state.syncing) return;
    state = state.copyWith(syncing: true, clearMessage: true);

    // Purge stale entries first.
    await OfflineQueueService.purgeExpired();

    final queue = OfflineQueueService.getAll();
    if (queue.isEmpty) {
      state = state.copyWith(syncing: false, pendingCount: 0);
      return;
    }

    final repo = _ref.read(guardRepositoryProvider);
    int synced = 0;
    int failed = 0;

    for (final mutation in queue) {
      try {
        await _executeMutation(repo, mutation);
        await OfflineQueueService.remove(mutation.id);
        synced++;
      } catch (e) {
        debugPrint('[OfflineSync] failed ${mutation.type.name}: $e');
        final updated = mutation.incrementRetry();
        if (updated.canRetry) {
          await OfflineQueueService.update(updated);
        } else {
          await OfflineQueueService.remove(mutation.id);
        }
        failed++;
      }
    }

    _refreshCount();

    // Invalidate dashboard providers so fresh data shows.
    if (synced > 0) {
      _ref.invalidate(guardDashboardProvider);
      _ref.invalidate(guardTodayVisitorsProvider);
    }

    final msg = failed == 0
        ? '$synced queued ${synced == 1 ? 'action' : 'actions'} synced'
        : '$synced synced, $failed failed';
    state = state.copyWith(syncing: false, lastSyncMessage: msg);
  }

  Future<void> _executeMutation(
    GuardRepository repo,
    OfflineMutation m,
  ) async {
    switch (m.type) {
      case OfflineMutationType.visitorCheckIn:
        await repo.checkInVisitor(
          name: m.params['name'] as String,
          phone: m.params['phone'] as String,
          visitTargets: (m.params['visitTargets'] as List)
              .cast<Map<String, dynamic>>(),
          visitorTypeApi: m.params['visitorTypeApi'] as String,
          vehicleNumber: m.params['vehicleNumber'] as String?,
          photo: m.params['photo'] as String?,
          awaitResidentApproval:
              m.params['awaitResidentApproval'] as bool? ?? true,
          clientMutationId: m.params['clientMutationId'] as String? ?? m.id,
        );
      case OfflineMutationType.visitorCheckOut:
        await repo.checkOutVisitor(
          m.params['visitorId'] as String,
          clientMutationId:
              m.params['clientMutationId'] as String? ?? m.id,
        );
      case OfflineMutationType.vehicleEntry:
        await repo.logGateVehicleEntry(
          registrationNumber: m.params['registrationNumber'] as String,
          kind: m.params['kind'] as String,
          villaId: m.params['villaId'] as String?,
          notes: m.params['notes'] as String?,
        );
      case OfflineMutationType.patrolStart:
        await repo.startPatrol(
          location: m.params['location'] as String,
          notes: m.params['notes'] as String?,
        );
      case OfflineMutationType.patrolCheckpoint:
        await repo.logPatrolCheckpoint(
          location: m.params['location'] as String,
          notes: m.params['notes'] as String?,
          issuesFound: m.params['issuesFound'] as bool? ?? false,
        );
    }
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final offlineSyncProvider =
    StateNotifierProvider<OfflineSyncNotifier, OfflineSyncState>(
  (ref) => OfflineSyncNotifier(ref),
);
