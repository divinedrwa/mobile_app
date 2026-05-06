import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/billing_cycle_current_model.dart';
import '../models/maintenance_due_model.dart';

class MaintenanceRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getFinancialDashboard({
    required int month,
    required int year,
    required bool isAdmin,
  }) async {
    try {
      final path = isAdmin
          ? '/maintenance-management/financial-dashboard'
          : '/residents/maintenance-dashboard';
      final response = await _dio.get(
        path,
        queryParameters: {'month': month, 'year': year},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch maintenance dashboard');
    }
  }

  Future<void> sendDuesReminders({
    required int month,
    required int year,
  }) async {
    try {
      await _dio.post(
        '/maintenance-management/send-dues-reminders',
        data: {'month': month, 'year': year},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send due reminders');
    }
  }

  Future<List<int>> downloadMaintenanceReportPdf({
    required int month,
    required int year,
    required bool isAdmin,
  }) async {
    try {
      final path = isAdmin
          ? '/maintenance-management/financial-dashboard/report-pdf'
          : '/residents/maintenance-dashboard/report-pdf';
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: {'month': month, 'year': year},
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to download maintenance report');
    }
  }

  Future<List<MaintenanceDueModel>> getPendingMaintenance() async {
    try {
      final response = await _dio.get('/residents/maintenance-pending');
      final data = response.data;
      final list = data is Map<String, dynamic>
          ? (data['pending'] as List? ?? const [])
          : const [];
      return list
          .whereType<Map>()
          .map((e) => MaintenanceDueModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch maintenance dues');
    }
  }

  Future<List<MaintenanceDueModel>> getMaintenanceHistory() async {
    try {
      final response = await _dio.get(ApiEndpoints.myMaintenance);
      final data = response.data;

      final List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        final nested = data['maintenance'] ?? data['history'] ?? data['items'] ?? data['data'];
        rawList = nested is List ? nested : const [];
      } else {
        rawList = const [];
      }

      return rawList
          .whereType<Map>()
          .map((e) => MaintenanceDueModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch maintenance history');
    }
  }

  Future<BillingCycleCurrent> getCurrentBillingCycle(String societyId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.billingCyclesCurrent(societyId: societyId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return BillingCycleCurrent.fromJson(data);
      }
      return BillingCycleCurrent.fromJson(const {});
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load billing cycle');
    }
  }

  /// Creates a Razorpay order on the server. Completing payment still requires gateway capture + webhook.
  Future<Map<String, dynamic>> createBillingOrder({
    required String cycleId,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.billingCreateOrder,
        data: {
          'cycleId': cycleId,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not start online payment');
    }
  }

  Future<void> payMaintenance({
    required String villaId,
    required int month,
    required int year,
    required double amount,
    required String paymentMode,
  }) async {
    try {
      await _dio.post(
        '/maintenance/payments',
        data: {
          'villaId': villaId,
          'month': month,
          'year': year,
          'amount': amount,
          'paymentDate': DateTime.now().toUtc().toIso8601String(),
          'paymentMode': paymentMode,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to process payment');
    }
  }
}
