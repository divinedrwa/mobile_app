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
      final data = res.data ?? {};
      // Backend returns { gates: [ { isActive, todayVisitors, assignedGuard } ] }.
      // Derive the flat overview stats the screen renders.
      final gates =
          (data['gates'] as List?)?.whereType<Map>().toList() ?? const [];
      int toInt(dynamic v) =>
          v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
      final todayVisitors =
          gates.fold<int>(0, (sum, g) => sum + toInt(g['todayVisitors']));
      final guardsOnDuty = gates.where((g) {
        final guard = g['assignedGuard'];
        return guard is Map && guard['isActive'] == true;
      }).length;
      return {
        'totalGates': gates.length,
        'activeGates': gates.where((g) => g['isActive'] == true).length,
        'todayVisitors': todayVisitors,
        'guardsOnDuty': guardsOnDuty,
        'gates': gates,
      };
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
