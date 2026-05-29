import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/notification_model.dart';

/// Repository for notification operations
class NotificationRepository {
  Dio get _dio => DioClient.dio;
  static const String _newBase = '/notifications';
  static const String _legacyBase = '/residents/notifications';
  static const String _legacyMyNotifications = '/residents/my-notifications';

  bool _isNotFound(DioException e) => e.response?.statusCode == 404;

  /// Get all notifications
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _dio.get(_newBase);
      final data = response.data;
      if (data == null) return [];

      final List<dynamic> rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        final nested = data['notifications'] ?? data['data'] ?? data['items'];
        rawList = nested is List ? nested : [];
      } else {
        rawList = [];
      }

      final out = <NotificationModel>[];
      for (final item in rawList) {
        if (item is! Map) continue;
        try {
          out.add(NotificationModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Skip malformed rows so one bad item doesn’t break the whole screen.
        }
      }
      return out;
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        try {
          final response = await _dio.get(_legacyMyNotifications);
          final data = response.data;
          if (data == null) return [];

          final List<dynamic> rawList;
          if (data is List) {
            rawList = data;
          } else if (data is Map<String, dynamic>) {
            final nested = data['notifications'] ?? data['data'] ?? data['items'];
            rawList = nested is List ? nested : [];
          } else {
            rawList = [];
          }

          final out = <NotificationModel>[];
          for (final item in rawList) {
            if (item is! Map) continue;
            try {
              out.add(NotificationModel.fromJson(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
          return out;
        } on DioException catch (legacyError) {
          throw mapDioException(legacyError, 'Failed to fetch notifications');
        }
      }
      throw mapDioException(e, 'Failed to fetch notifications');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.patch('$_newBase/$notificationId/read');
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        try {
          await _dio.patch('$_legacyBase/$notificationId/read');
          return;
        } on DioException catch (legacyError) {
          throw mapDioException(
            legacyError,
            'Failed to mark notification as read',
          );
        }
      }
      throw mapDioException(e, 'Failed to mark notification as read');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _dio.post('$_newBase/read-all');
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        try {
          await _dio.post('$_legacyBase/read-all');
          return;
        } on DioException catch (legacyError) {
          throw mapDioException(
            legacyError,
            'Failed to mark all notifications as read',
          );
        }
      }
      throw mapDioException(e, 'Failed to mark all notifications as read');
    }
  }

  /// Delete notification — backend has no DELETE endpoint; this is a local-only
  /// dismiss. The notification will reappear on the next full fetch but the UI
  /// removes it immediately for a snappy UX.
  Future<void> deleteNotification(String notificationId) async {
    // No-op: backend does not expose DELETE /notifications/:id.
    // The provider removes it from local state.
  }

  /// Get unread count (backend embeds `unreadCount` on `GET /notifications`).
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(
        _newBase,
        queryParameters: const {'limit': 1, 'skip': 0},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final n = data['unreadCount'];
        if (n is int) return n;
        if (n is num) return n.toInt();
      }
      return 0;
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        return 0;
      }
      throw mapDioException(e, 'Failed to get unread count');
    }
  }
}
