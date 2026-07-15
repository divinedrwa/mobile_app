import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notification_preferences_repository.dart';

class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.items = const [],
    this.isLoading = true,
    this.error,
    this.busy = const {},
  });

  final List<NotificationCategoryPref> items;
  final bool isLoading;
  final String? error;

  /// Categories with an in-flight toggle (disables that switch).
  final Set<String> busy;

  /// Only categories the user is allowed to change.
  List<NotificationCategoryPref> get mutableItems =>
      items.where((e) => e.mutable).toList();

  NotificationPreferencesState copyWith({
    List<NotificationCategoryPref>? items,
    bool? isLoading,
    String? error,
    Set<String>? busy,
    bool clearError = false,
  }) {
    return NotificationPreferencesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesNotifier(this._repo)
      : super(const NotificationPreferencesState()) {
    load();
  }

  final NotificationPreferencesRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.getPreferences();
      state = state.copyWith(items: items, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load notification preferences.',
      );
    }
  }

  /// Optimistically toggle a category; revert on failure.
  Future<void> setCategory(String category, bool pushEnabled) async {
    final previous = state.items;
    state = state.copyWith(
      items: state.items
          .map((e) =>
              e.category == category ? e.copyWith(pushEnabled: pushEnabled) : e)
          .toList(),
      busy: {...state.busy, category},
      clearError: true,
    );
    try {
      await _repo.setPreference(category: category, pushEnabled: pushEnabled);
    } catch (_) {
      state = state.copyWith(
        items: previous,
        error: 'Could not update that preference. Please try again.',
      );
    } finally {
      state = state.copyWith(busy: {...state.busy}..remove(category));
    }
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
  (ref) => NotificationPreferencesRepository(),
);

final notificationPreferencesProvider = StateNotifierProvider.autoDispose<
    NotificationPreferencesNotifier, NotificationPreferencesState>(
  (ref) => NotificationPreferencesNotifier(
    ref.read(notificationPreferencesRepositoryProvider),
  ),
);

/// Human-friendly label for a backend NotificationCategory enum value.
String notificationCategoryLabel(String category) {
  switch (category) {
    case 'NOTICE':
      return 'Notices';
    case 'VISITOR':
      return 'Visitors';
    case 'COMPLAINT':
      return 'Complaints';
    case 'PARCEL':
      return 'Parcels & deliveries';
    case 'AMENITY':
      return 'Amenity bookings';
    case 'POLL':
      return 'Polls';
    case 'WATER_SUPPLY':
      return 'Water supply';
    case 'GARBAGE':
      return 'Garbage collection';
    case 'MAINTENANCE':
      return 'Maintenance updates';
    case 'EXPENSE':
      return 'Society expenses';
    case 'PROJECT':
      return 'Special projects';
    case 'BROADCAST':
      return 'Announcements';
    case 'OTHER':
      return 'Other';
    default:
      return category;
  }
}
