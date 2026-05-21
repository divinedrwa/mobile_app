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
