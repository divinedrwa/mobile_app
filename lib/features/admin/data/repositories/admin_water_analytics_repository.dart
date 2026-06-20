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
      final data = res.data ?? {};
      // Backend nests the figures under `summary` (and uses `avgDurationMinutes`,
      // with the gate count in `gateStats`); expose the flat keys the screen reads.
      final summary = (data['summary'] as Map?) ?? const {};
      final gateStats = (data['gateStats'] as List?) ?? const [];
      return {
        ...Map<String, dynamic>.from(data),
        'totalEvents': summary['totalEvents'] ?? 0,
        'onEvents': summary['onEvents'] ?? 0,
        'offEvents': summary['offEvents'] ?? 0,
        'completedCycles': summary['completedCycles'] ?? 0,
        'averageDurationMinutes': summary['avgDurationMinutes'] ?? 0,
        'totalGates': gateStats.length,
        'gateStats': gateStats,
      };
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
      if (data is Map && data['usageData'] is List) {
        return (data['usageData'] as List)
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

  Future<List<Map<String, dynamic>>> getHourlyPattern({int days = 30}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.waterSupplyAnalyticsHourlyPattern,
        queryParameters: {'days': days},
      );
      final data = res.data;
      List<Map<String, dynamic>> pattern = [];
      if (data is Map && data['pattern'] is List) {
        pattern = (data['pattern'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (data is Map && data['hourlyPattern'] is List) {
        pattern = (data['hourlyPattern'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (data is List) {
        pattern = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      // Prefer peak hours when present; otherwise top hours by activity.
      if (data is Map && data['peakHours'] is List) {
        final peaks = (data['peakHours'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (peaks.isNotEmpty) return peaks;
      }
      pattern.sort(
        (a, b) => _toInt(b['totalEvents']).compareTo(_toInt(a['totalEvents'])),
      );
      return pattern.take(8).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load hourly pattern');
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<List<Map<String, dynamic>>> getGatePerformance(
      {int days = 30}) async {
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
