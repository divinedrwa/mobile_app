import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminIncidentRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getIncidents({
    int limit = 200,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.incidents,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load incidents');
    }
  }

  Future<void> resolveIncident(String id) async {
    try {
      await _dio.patch(
        ApiEndpoints.incidentResolve(id),
        data: {'resolvedAt': DateTime.now().toUtc().toIso8601String()},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to resolve incident');
    }
  }
}
