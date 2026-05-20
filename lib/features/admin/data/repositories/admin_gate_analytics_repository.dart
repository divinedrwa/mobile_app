import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminGateAnalyticsRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getOverview() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gateAnalyticsOverview,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load gate analytics');
    }
  }

  Future<Map<String, dynamic>> getVisitorStatistics({int days = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gateAnalyticsVisitorStats,
        queryParameters: {'days': days},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load visitor statistics');
    }
  }

  Future<Map<String, dynamic>> getPeakHours({int days = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gateAnalyticsPeakHours,
        queryParameters: {'days': days},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load peak hours');
    }
  }

  Future<Map<String, dynamic>> getDailyTrend({int days = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gateAnalyticsDailyTrend,
        queryParameters: {'days': days},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load daily trend');
    }
  }
}
