import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/admin_dashboard_model.dart';

class AdminDashboardRepository {
  Dio get _dio => DioClient.dio;

  Future<AdminDashboardModel> getDashboard() async {
    try {
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;

      final results = await Future.wait([
        _dio.get(ApiEndpoints.adminVisitors),
        _dio.get(ApiEndpoints.adminParcels),
        _dio.get(ApiEndpoints.adminComplaints),
        _dio.get(ApiEndpoints.adminFinancialDashboard, queryParameters: {
          'month': month,
          'year': year,
        }),
      ]);

      // Visitors — extract todayCount from response
      final visitorsData = results[0].data;
      final todayVisitors = _extractInt(visitorsData, 'todayCount') ??
          _extractListLength(visitorsData);

      // Parcels — extract pendingCount
      final parcelsData = results[1].data;
      final pendingParcels = _extractInt(parcelsData, 'pendingCount') ??
          _extractListLength(parcelsData);

      // Complaints — extract openCount
      final complaintsData = results[2].data;
      final openComplaints = _extractInt(complaintsData, 'openCount') ??
          _extractListLength(complaintsData);

      // Financial dashboard — extract summary
      final finData = results[3].data;
      final summary = finData is Map<String, dynamic>
          ? (finData['summary'] as Map<String, dynamic>? ?? finData)
          : <String, dynamic>{};

      final totalExpected = _toDouble(summary['totalExpected']);
      final totalCollected = _toDouble(summary['totalCollected']);
      final collectionRate = totalExpected > 0
          ? (totalCollected / totalExpected * 100)
          : 0.0;

      return AdminDashboardModel(
        todayVisitors: todayVisitors,
        pendingParcels: pendingParcels,
        openComplaints: openComplaints,
        totalExpected: totalExpected,
        totalCollected: totalCollected,
        collectionRate: collectionRate,
        paidCount: _extractInt(summary, 'paidCount') ?? 0,
        unpaidCount: _extractInt(summary, 'unpaidCount') ?? 0,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch admin dashboard');
    }
  }

  int? _extractInt(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final v = data[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return null;
  }

  int _extractListLength(dynamic data) {
    if (data is List) return data.length;
    if (data is Map<String, dynamic>) {
      final items = data['data'] ?? data['items'] ?? data['results'];
      if (items is List) return items.length;
      final total = data['total'] ?? data['count'];
      if (total is int) return total;
      if (total is num) return total.toInt();
    }
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
