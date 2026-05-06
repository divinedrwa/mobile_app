import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/amenity_model.dart';
import '../models/amenity_booking_model.dart';
import '../repositories/amenity_booking_repository.dart';

/// Amenity Booking State Notifier
class AmenityBookingNotifier extends StateNotifier<AsyncValue<List<AmenityBookingModel>>> {
  final AmenityBookingRepository _repository;

  AmenityBookingNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchBookings();
  }

  /// Fetch all bookings
  Future<void> fetchBookings() async {
    state = const AsyncValue.loading();
    try {
      final bookings = await _repository.getBookings();
      state = AsyncValue.data(bookings);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Fetch upcoming bookings
  Future<void> fetchUpcomingBookings() async {
    state = const AsyncValue.loading();
    try {
      final bookings = await _repository.getUpcomingBookings();
      state = AsyncValue.data(bookings);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Fetch past bookings
  Future<void> fetchPastBookings() async {
    state = const AsyncValue.loading();
    try {
      final bookings = await _repository.getPastBookings();
      state = AsyncValue.data(bookings);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Cancel booking
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _repository.cancelBooking(bookingId, reason: reason);
      await fetchBookings();
      return true;
    } catch (e) {
      debugPrint('Error canceling booking: $e');
      return false;
    }
  }

  /// Get upcoming count
  int getUpcomingCount() {
    return state.when(
      data: (bookings) {
        final now = DateTime.now();
        return bookings.where((b) {
          return b.bookingDate.isAfter(now) && b.status == BookingStatus.confirmed;
        }).length;
      },
      loading: () => 0,
      error: (_, _) => 0,
    );
  }
}

/// Amenity Booking Provider
final amenityBookingProvider = StateNotifierProvider<AmenityBookingNotifier, AsyncValue<List<AmenityBookingModel>>>(
  (ref) => AmenityBookingNotifier(AmenityBookingRepository()),
);

/// Upcoming bookings count provider
final upcomingBookingsCountProvider = Provider<int>((ref) {
  return ref.watch(amenityBookingProvider).when(
        data: (bookings) {
          final now = DateTime.now();
          return bookings
              .where((b) => b.bookingDate.isAfter(now) && b.status == BookingStatus.confirmed)
              .length;
        },
        loading: () => 0,
        error: (_, _) => 0,
      );
});

final amenitiesProvider = FutureProvider<List<AmenityModel>>((ref) async {
  return ref.watch(amenityRepositoryProvider).getAmenities();
});

class AmenityBookingActionNotifier extends StateNotifier<AsyncValue<void>> {
  AmenityBookingActionNotifier(this._repository) : super(const AsyncValue.data(null));

  final AmenityBookingRepository _repository;

  Future<bool> createBooking({
    required String amenityId,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createBooking(
        amenityId: amenityId,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final amenityRepositoryProvider = Provider<AmenityBookingRepository>(
  (ref) => AmenityBookingRepository(),
);

final amenityBookingActionProvider =
    StateNotifierProvider<AmenityBookingActionNotifier, AsyncValue<void>>(
  (ref) => AmenityBookingActionNotifier(ref.watch(amenityRepositoryProvider)),
);
