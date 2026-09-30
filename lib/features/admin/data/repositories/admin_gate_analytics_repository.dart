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
      final gates =
          (data['gates'] as List?)?.whereType<Map>().toList() ?? const [];
      final totals = data['totals'] is Map ? Map<String, dynamic>.from(data['totals'] as Map) : null;
      int toInt(dynamic v) =>
          v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
      int sum(String key) => gates.fold<int>(0, (s, g) => s + toInt(g[key]));
      // "On duty" means an active shift right now, not just an active account.
      final guardsOnShift = gates.where((g) {
        final guard = g['assignedGuard'];
        return guard is Map && guard['onShift'] == true;
      }).length;
      return {
        'totalGates': totals?['gates'] ?? gates.length,
        'activeGates': totals?['activeGates'] ?? gates.where((g) => g['isActive'] == true).length,
        'todayVisitors': totals?['todayEntries'] ?? sum('todayVisitors'),
        'todayRequests': totals?['todayRequests'] ?? sum('todayRequests'),
        'insideNow': totals?['insideNow'] ?? sum('activeVisitors'),
        'waitingNow': totals?['waitingNow'] ?? sum('waitingNow'),
        'guardsOnDuty': totals?['guardsOnShift'] ?? guardsOnShift,
        'gates': gates,
      };
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load gate analytics');
    }
  }

  Future<Map<String, dynamic>> getVisitorStatistics({int days = 30}) async {
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

  Future<Map<String, dynamic>> getPeakHours({int days = 30}) async {
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
