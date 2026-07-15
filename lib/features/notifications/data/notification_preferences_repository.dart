import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// L3 — a single category's push preference. `mutable` is false for critical
/// categories (SOS, PAYMENT, SYSTEM), which the backend always delivers.
class NotificationCategoryPref {
  const NotificationCategoryPref({
    required this.category,
    required this.pushEnabled,
    required this.mutable,
  });

  final String category;
  final bool pushEnabled;
  final bool mutable;

  factory NotificationCategoryPref.fromJson(Map<String, dynamic> json) {
    return NotificationCategoryPref(
      category: (json['category'] ?? '').toString(),
      pushEnabled: json['pushEnabled'] == true,
      mutable: json['mutable'] == true,
    );
  }

  NotificationCategoryPref copyWith({bool? pushEnabled}) {
    return NotificationCategoryPref(
      category: category,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      mutable: mutable,
    );
  }
}

class NotificationPreferencesRepository {
  Dio get _dio => DioClient.dio;

  Future<List<NotificationCategoryPref>> getPreferences() async {
    final response = await _dio.get(ApiEndpoints.notificationPreferences);
    final list = (response.data['preferences'] as List?) ?? const [];
    return list
        .map((e) =>
            NotificationCategoryPref.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Mute/unmute a single category. The backend rejects critical categories.
  Future<void> setPreference({
    required String category,
    required bool pushEnabled,
  }) async {
    await _dio.put(
      ApiEndpoints.notificationPreferences,
      data: {'category': category, 'pushEnabled': pushEnabled},
    );
  }
}
