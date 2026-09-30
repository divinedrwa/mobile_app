import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/offline_queue_service.dart';
import 'guard_offline_sync_notifier.dart';
import 'guard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of a guard check-out attempt that may queue offline.
class GuardCheckOutResult {
  const GuardCheckOutResult({required this.queuedOffline});

  final bool queuedOffline;
}

/// Runs [online]; with no network, saves the action ([type] + [params]) to the
/// offline queue instead. Returns true when it was queued offline.
Future<bool> runOrQueueOffline(
  WidgetRef ref, {
  required OfflineMutationType type,
  required Map<String, dynamic> params,
  required Future<void> Function() online,
}) async {
  try {
    await online();
    return false;
  } on NetworkException {
    await ref.read(offlineSyncProvider.notifier).enqueue(
          OfflineMutation(
            id: const Uuid().v4(),
            type: type,
            params: params,
            createdAt: DateTime.now(),
          ),
        );
    return true;
  }
}

/// Check out a visitor online, or enqueue for offline sync on network failure.
Future<GuardCheckOutResult> guardCheckOutWithOfflineFallback(
  WidgetRef ref,
  String visitorId,
) async {
  final clientMutationId = const Uuid().v4();
  try {
    await ref.read(guardRepositoryProvider).checkOutVisitor(
          visitorId,
          clientMutationId: clientMutationId,
        );
    return const GuardCheckOutResult(queuedOffline: false);
  } on NetworkException {
    await ref.read(offlineSyncProvider.notifier).enqueue(
          OfflineMutation(
            id: clientMutationId,
            type: OfflineMutationType.visitorCheckOut,
            params: {
              'visitorId': visitorId,
              'clientMutationId': clientMutationId,
            },
            createdAt: DateTime.now(),
          ),
        );
    return const GuardCheckOutResult(queuedOffline: true);
  }
}
