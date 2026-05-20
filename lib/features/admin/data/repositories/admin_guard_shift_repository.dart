import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminGuardShiftRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all guard shifts with guard & gate details.
  Future<List<Map<String, dynamic>>> getShifts() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminGuardShifts,
      );
      final list = res.data?['shifts'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load guard shifts');
    }
  }

  /// Create a new guard shift.
  /// [startTime] and [endTime] are ISO 8601 datetime strings.
  Future<void> createShift({
    required String guardId,
    required String gateId,
    required String shiftType,
    required String startTime,
    required String endTime,
    bool isRecurring = false,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminGuardShifts,
        data: {
          'guardId': guardId,
          'gateId': gateId,
          'shiftType': shiftType,
          'startTime': startTime,
          'endTime': endTime,
          'isRecurring': isRecurring,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create shift');
    }
  }

  /// Update an existing guard shift.
  Future<void> updateShift(
    String id, {
    String? guardId,
    String? gateId,
    String? shiftType,
    String? startTime,
    String? endTime,
    bool? isRecurring,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminGuardShiftById(id),
        data: {
          if (guardId != null) 'guardId': guardId,
          if (gateId != null) 'gateId': gateId,
          if (shiftType != null) 'shiftType': shiftType,
          if (startTime != null) 'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
          if (isRecurring != null) 'isRecurring': isRecurring,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update shift');
    }
  }

  /// Delete a guard shift.
  Future<void> deleteShift(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminGuardShiftById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete shift');
    }
  }
}
