import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/utils/persistent_list_cache.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

String _errorMessage(Object e) {
  if (e is AppException) return e.message;
  return 'Something went wrong. Please try again.';
}

/// Persistent cache name for the notifications inbox (scoped by society + user).
const _notificationsCacheName = 'notifications';

/// Notification State Notifier
class NotificationNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final NotificationRepository _repository;

  NotificationNotifier(this._repository) : super(const AsyncValue.loading()) {
    // Seed from the persistent cache so the inbox paints cached content on a
    // cold start instead of a blank/skeleton frame; the network fetch then
    // revalidates. A corrupt/schema-incompatible entry silently falls through.
    final seeded = _readCache();
    if (seeded != null && seeded.isNotEmpty) {
      state = AsyncValue.data(seeded);
    }
    fetchNotifications();
  }

  static List<NotificationModel>? _readCache() {
    final key = PersistentListCache.scopedKey(_notificationsCacheName);
    if (key == null) return null;
    return PersistentListCache.read<List<NotificationModel>>(key, (json) {
      return (json as List)
          .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  Future<void> _writeCache(List<NotificationModel> notifications) async {
    final key = PersistentListCache.scopedKey(_notificationsCacheName);
    if (key == null) return;
    await PersistentListCache.write(
      key,
      notifications.map((n) => n.toJson()).toList(),
    );
  }

  /// Fetch all notifications.
  /// First load shows loading (unless cache-seeded); retries keep the previous
  /// list if the request fails (better on flaky mobile networks). On success
  /// the list is persisted for the next cold start.
  Future<void> fetchNotifications() async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncValue.loading();
    }
    try {
      final notifications = await _repository.getNotifications();
      state = AsyncValue.data(notifications);
      await _writeCache(notifications);
    } catch (e, stack) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  /// Mark notification as read. Returns null on success, error message on failure.
  Future<String?> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);

      // Update local state
      state.whenData((notifications) {
        final updatedNotifications = notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();
        state = AsyncValue.data(updatedNotifications);
      });

      return null;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return _errorMessage(e);
    }
  }

  /// Mark all notifications as read. Returns null on success, error message on failure.
  Future<String?> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();

      // Update local state
      state.whenData((notifications) {
        final updatedNotifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
        state = AsyncValue.data(updatedNotifications);
      });

      return null;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return _errorMessage(e);
    }
  }

  /// Delete notification. Returns null on success, error message on failure.
  Future<String?> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);

      // Update local state
      state.whenData((notifications) {
        final updatedNotifications = notifications.where((n) => n.id != notificationId).toList();
        state = AsyncValue.data(updatedNotifications);
      });

      return null;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return _errorMessage(e);
    }
  }

  /// Get unread count
  int getUnreadCount() {
    return state.when(
      data: (notifications) => notifications.where((n) => !n.isRead).length,
      loading: () => 0,
      error: (_, _) => 0,
    );
  }
}

/// Notification Provider
final notificationProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<List<NotificationModel>>>(
  (ref) => NotificationNotifier(NotificationRepository()),
);

/// Unread count — must watch [notificationProvider] state, not the notifier identity.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
