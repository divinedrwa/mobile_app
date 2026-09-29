import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminPatrolRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getPatrols() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminGuardPatrols,
      );
      final list = res.data?['patrols'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load patrols');
    }
  }

  /// [scheduledTime] must be a UTC ISO string.
  Future<void> createPatrol({
    required String guardId,
    required String gateId,
    required String checkpointName,
    required String scheduledTime,
    String? checkpointLocation,
    String? notes,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminGuardPatrols,
        data: {
          'guardId': guardId,
          'gateId': gateId,
          'checkpointName': checkpointName,
          'scheduledTime': scheduledTime,
          if (checkpointLocation != null && checkpointLocation.trim().isNotEmpty)
            'checkpointLocation': checkpointLocation.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to schedule patrol');
    }
  }

  Future<void> updatePatrol(
    String id, {
    String? checkpointName,
    String? checkpointLocation,
    String? scheduledTime,
    String? notes,
  }) async {
    try {
      await _dio.put(
        ApiEndpoints.adminGuardPatrolById(id),
        data: {
          if (checkpointName != null) 'checkpointName': checkpointName,
          if (checkpointLocation != null)
            'checkpointLocation': checkpointLocation.trim(),
          if (scheduledTime != null) 'scheduledTime': scheduledTime,
          if (notes != null) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update patrol');
    }
  }

  Future<void> deletePatrol(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminGuardPatrolById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete patrol');
    }
  }

  Future<void> updatePatrolStatus(
    String id, {
    required String status,
    String? notes,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminGuardPatrolStatus(id),
        data: {
          'status': status,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update patrol status');
    }
  }
}
