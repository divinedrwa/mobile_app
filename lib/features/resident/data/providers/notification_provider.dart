import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// Notification State Notifier
class NotificationNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final NotificationRepository _repository;

  NotificationNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchNotifications();
  }

  /// Fetch all notifications.
  /// First load shows loading; retries keep the previous list if the request fails (better on flaky mobile networks).
  Future<void> fetchNotifications() async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncValue.loading();
    }
    try {
      final notifications = await _repository.getNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, stack) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
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
      
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      
      // Update local state
      state.whenData((notifications) {
        final updatedNotifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
        state = AsyncValue.data(updatedNotifications);
      });
      
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);
      
      // Update local state
      state.whenData((notifications) {
        final updatedNotifications = notifications.where((n) => n.id != notificationId).toList();
        state = AsyncValue.data(updatedNotifications);
      });
      
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
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
