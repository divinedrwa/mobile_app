import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminAppAnalyticsRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getSummary({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsSummary,
        queryParameters: {'days': days},
      );
      return (res.data?['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load app analytics summary');
    }
  }

  Future<List<Map<String, dynamic>>> getDailyTrend({int days = 14}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsDailyTrend,
        queryParameters: {'days': days},
      );
      final list = res.data?['trendData'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load daily trend');
    }
  }

  Future<List<Map<String, dynamic>>> getTopScreens({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsScreens,
        queryParameters: {'days': days},
      );
      final list = res.data?['screens'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load screen analytics');
    }
  }

  Future<List<Map<String, dynamic>>> getFlows({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsFlows,
        queryParameters: {'days': days},
      );
      final list = res.data?['flows'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load flow analytics');
    }
  }

  Future<List<Map<String, dynamic>>> getActions({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsActions,
        queryParameters: {'days': days},
      );
      final list = res.data?['actions'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load business actions');
    }
  }

  Future<Map<String, dynamic>> getErrors({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsErrors,
        queryParameters: {'days': days},
      );
      return {
        'errors': (res.data?['errors'] as List?) ?? [],
        'totals': (res.data?['totals'] as Map?)?.cast<String, dynamic>() ?? {},
      };
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load error analytics');
    }
  }

  Future<Map<String, dynamic>> getInsights({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsInsights,
        queryParameters: {'days': days},
      );
      return (res.data?['insights'] as Map?)?.cast<String, dynamic>() ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load analytics insights');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveUsers({int days = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsActiveUsers,
        queryParameters: {'days': days, 'limit': 50},
      );
      final list = res.data?['users'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load active users');
    }
  }

  Future<Map<String, dynamic>> getUserEngagement({int days = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.appAnalyticsUserEngagement,
        queryParameters: {'days': days, 'limit': 50},
      );
      return (res.data?['engagement'] as Map?)?.cast<String, dynamic>() ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load user engagement');
    }
  }
}
