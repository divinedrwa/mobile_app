import 'package:flutter_test/flutter_test.dart';
import 'package:divine_app/features/notifications/data/notification_preferences_repository.dart';
import 'package:divine_app/features/notifications/presentation/providers/notification_preferences_provider.dart';

void main() {
  group('NotificationCategoryPref.fromJson', () {
    test('parses an enabled mutable category', () {
      final pref = NotificationCategoryPref.fromJson({
        'category': 'NOTICE',
        'pushEnabled': true,
        'mutable': true,
      });
      expect(pref.category, 'NOTICE');
      expect(pref.pushEnabled, isTrue);
      expect(pref.mutable, isTrue);
    });

    test('treats missing flags as false', () {
      final pref = NotificationCategoryPref.fromJson({'category': 'SOS'});
      expect(pref.pushEnabled, isFalse);
      expect(pref.mutable, isFalse);
    });

    test('copyWith overrides pushEnabled only', () {
      const pref =
          NotificationCategoryPref(category: 'VISITOR', pushEnabled: true, mutable: true);
      final muted = pref.copyWith(pushEnabled: false);
      expect(muted.pushEnabled, isFalse);
      expect(muted.category, 'VISITOR');
      expect(muted.mutable, isTrue);
    });
  });

  group('notificationCategoryLabel', () {
    test('maps known categories to friendly labels', () {
      expect(notificationCategoryLabel('WATER_SUPPLY'), 'Water supply');
      expect(notificationCategoryLabel('PARCEL'), 'Parcels & deliveries');
    });

    test('falls back to the raw value for unknown categories', () {
      expect(notificationCategoryLabel('SOMETHING_NEW'), 'SOMETHING_NEW');
    });
  });
}
