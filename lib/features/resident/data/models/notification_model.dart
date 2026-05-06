import 'package:flutter/material.dart';

/// Notification model
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actionUrl,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final readAt = json['readAt'];
    final categoryRaw =
        json['category']?.toString() ?? json['type']?.toString() ?? 'general';
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      type: NotificationType.fromCategory(categoryRaw),
      createdAt: _parseCreatedAt(json['createdAt']),
      isRead: _parseBool(json['isRead']) || (readAt != null && readAt.toString().isNotEmpty),
      actionUrl: json['actionUrl']?.toString(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
    );
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      final ms = value < 2000000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value == 'true' || value == '1';
    if (value is num) return value != 0;
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.value,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      if (actionUrl != null) 'actionUrl': actionUrl,
      if (data != null) 'data': data,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? actionUrl,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      data: data ?? this.data,
    );
  }
}

/// Notification type enum
enum NotificationType {
  general('general', Icons.notifications, Colors.blue),
  alert('alert', Icons.warning, Colors.orange),
  emergency('emergency', Icons.emergency, Colors.red),
  maintenance('maintenance', Icons.build, Colors.purple),
  event('event', Icons.event, Colors.green),
  payment('payment', Icons.payment, Colors.teal),
  visitor('visitor', Icons.person, Colors.indigo),
  parcel('parcel', Icons.local_shipping, Colors.brown);

  final String value;
  final IconData icon;
  final Color color;

  const NotificationType(this.value, this.icon, this.color);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => NotificationType.general,
    );
  }

  /// Maps Prisma `NotificationCategory` (API field `category`) to UI type.
  static NotificationType fromCategory(String? category) {
    final c = (category ?? '').trim().toUpperCase();
    switch (c) {
      case 'VISITOR':
        return NotificationType.visitor;
      case 'SOS':
        return NotificationType.emergency;
      case 'PAYMENT':
        return NotificationType.payment;
      case 'PARCEL':
        return NotificationType.parcel;
      case 'AMENITY':
        return NotificationType.event;
      case 'NOTICE':
      case 'BROADCAST':
        return NotificationType.event;
      case 'SYSTEM':
        return NotificationType.general;
      default:
        return NotificationType.fromString(c);
    }
  }
}
