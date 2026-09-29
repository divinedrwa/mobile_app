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

  /// Create a new guard shift (single).
  Future<void> createShift({
    required String guardId,
    required String gateId,
    required String shiftType,
    required int recurringStartMinutes,
    required int recurringEndMinutes,
    String? contactPhone,
    bool recurringDaily = true,
    String? startTime,
    String? endTime,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminGuardShifts,
        data: {
          'guardId': guardId,
          'gateId': gateId,
          'shiftType': shiftType,
          'recurringDaily': recurringDaily,
          if (recurringDaily) ...{
            'recurringStartMinutes': recurringStartMinutes,
            'recurringEndMinutes': recurringEndMinutes,
          } else ...{
            'startTime': startTime,
            'endTime': endTime,
          },
          if (contactPhone != null && contactPhone.trim().isNotEmpty)
            'contactPhone': contactPhone.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create shift');
    }
  }

  /// Generate full 24h roster (8h → 3 shifts, 12h → 2 shifts).
  Future<List<Map<String, dynamic>>> generateRoster({
    required String guardId,
    required String gateId,
    required int shiftDurationHours,
    required int dayStartMinutes,
    List<String?>? contactPhones,
    String? notes,
    bool replaceExisting = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.adminGuardShifts}/generate-roster',
        data: {
          'guardId': guardId,
          'gateId': gateId,
          'shiftDurationHours': shiftDurationHours,
          'dayStartMinutes': dayStartMinutes,
          if (contactPhones != null)
            'contactPhones':
                contactPhones.map((p) => p?.trim().isEmpty == true ? null : p?.trim()).toList(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          'replaceExisting': replaceExisting,
        },
      );
      final list = res.data?['shifts'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to generate roster');
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
    String? contactPhone,
    bool? isRecurring,
    int? recurringStartMinutes,
    int? recurringEndMinutes,
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
          // Backend accepts null to clear, but rejects an empty string.
          if (contactPhone != null)
            'contactPhone':
                contactPhone.trim().isEmpty ? null : contactPhone.trim(),
          if (isRecurring != null) 'recurringDaily': isRecurring,
          if (recurringStartMinutes != null)
            'recurringStartMinutes': recurringStartMinutes,
          if (recurringEndMinutes != null)
            'recurringEndMinutes': recurringEndMinutes,
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
