import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/amenity_model.dart';
import '../models/amenity_booking_model.dart';

/// Repository for amenity booking operations
class AmenityBookingRepository {
  Dio get _dio => DioClient.dio;

  Future<List<AmenityModel>> getAmenities() async {
    try {
      final response = await _dio.get('/residents/my-amenities');
      final list = response.data is List
          ? response.data as List
          : (response.data['amenities'] as List? ?? []);

      return list
          .whereType<Map>()
          .map((json) => AmenityModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch amenities');
    }
  }

  /// Get all bookings
  Future<List<AmenityBookingModel>> getBookings() async {
    try {
      final response = await _dio.get('/residents/my-bookings');
      
      // Backend might return { "bookings": [...] } or direct array
      final bookingsList = response.data is List 
          ? response.data as List
          : (response.data['bookings'] as List? ?? []);
      
      return bookingsList
          .map((json) => AmenityBookingModel.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch bookings');
    }
  }

  /// Upcoming bookings (server returns full list; we filter client-side).
  Future<List<AmenityBookingModel>> getUpcomingBookings() async {
    final all = await getBookings();
    final now = DateTime.now();
    final upcoming = all.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      return !b.bookingDate.isBefore(now);
    }).toList()
      ..sort((a, b) => a.bookingDate.compareTo(b.bookingDate));
    return upcoming;
  }

  /// Past bookings (server returns full list; we filter client-side).
  Future<List<AmenityBookingModel>> getPastBookings() async {
    final all = await getBookings();
    final now = DateTime.now();
    final past = all.where((b) {
      if (b.status == BookingStatus.cancelled) return true;
      return b.bookingDate.isBefore(now);
    }).toList()
      ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    return past;
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _dio.patch(
        '/residents/bookings/$bookingId/cancel',
        data: {
          'reason': ?reason,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to cancel booking');
    }
  }

  Future<void> createBooking({
    required String amenityId,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) async {
    try {
      await _dio.post(
        '/residents/book-amenity',
        data: {
          'amenityId': amenityId,
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create booking');
    }
  }
}
