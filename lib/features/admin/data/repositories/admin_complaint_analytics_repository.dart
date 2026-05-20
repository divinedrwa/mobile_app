import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminComplaintAnalyticsRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getSummary({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.complaintAnalyticsSummary,
        queryParameters: {'days': days},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load complaint summary');
    }
  }

  Future<List<Map<String, dynamic>>> getByCategory({int days = 30}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.complaintAnalyticsByCategory,
        queryParameters: {'days': days},
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['categories'] is List) {
        return (data['categories'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load complaints by category');
    }
  }

  Future<List<Map<String, dynamic>>> getPending({int limit = 20}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.complaintAnalyticsPending,
        queryParameters: {'limit': limit},
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['complaints'] is List) {
        return (data['complaints'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load pending complaints');
    }
  }

  Future<List<Map<String, dynamic>>> getTrend({int months = 6}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.complaintAnalyticsTrend,
        queryParameters: {'months': months},
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['trend'] is List) {
        return (data['trend'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load complaint trend');
    }
  }
}
