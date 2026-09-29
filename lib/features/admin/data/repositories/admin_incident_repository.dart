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

  /// [severity] is one of LOW, MEDIUM, HIGH, CRITICAL.
  Future<void> createIncident({
    required String title,
    required String description,
    required String severity,
    String? location,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.incidents,
        data: {
          'title': title,
          'description': description,
          'severity': severity,
          if (location != null && location.trim().isNotEmpty)
            'location': location.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to report incident');
    }
  }

  Future<void> updateIncident(
    String id, {
    String? title,
    String? description,
    String? severity,
    String? location,
  }) async {
    try {
      await _dio.put(
        ApiEndpoints.incidentById(id),
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (severity != null) 'severity': severity,
          if (location != null) 'location': location.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update incident');
    }
  }

  Future<void> deleteIncident(String id) async {
    try {
      await _dio.delete(ApiEndpoints.incidentById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete incident');
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
