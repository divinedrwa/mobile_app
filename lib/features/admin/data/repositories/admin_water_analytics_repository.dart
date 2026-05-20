import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminWaterAnalyticsRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getOverview({int days = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.waterSupplyAnalyticsOverview,
        queryParameters: {'days': days},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load water supply overview');
    }
  }

  Future<List<Map<String, dynamic>>> getDailyUsage({int days = 7}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.waterSupplyAnalyticsDailyUsage,
        queryParameters: {'days': days},
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['dailyUsage'] is List) {
        return (data['dailyUsage'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load daily usage');
    }
  }

  Future<List<Map<String, dynamic>>> getHourlyPattern({int days = 7}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.waterSupplyAnalyticsHourlyPattern,
        queryParameters: {'days': days},
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['hourlyPattern'] is List) {
        return (data['hourlyPattern'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load hourly pattern');
    }
  }

  Future<List<Map<String, dynamic>>> getGatePerformance(
      {int days = 7}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.waterSupplyAnalyticsGatePerformance,
        queryParameters: {'days': days},
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['gatePerformance'] is List) {
        return (data['gatePerformance'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load gate performance');
    }
  }
}
