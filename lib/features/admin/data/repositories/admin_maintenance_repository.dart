import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminMaintenanceRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch the admin financial dashboard for a given period.
  Future<Map<String, dynamic>> getFinancialDashboard({
    required int month,
    required int year,
    String? maintenanceCollectionCycleId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminFinancialDashboard,
        queryParameters: {
          'month': month,
          'year': year,
          if (maintenanceCollectionCycleId != null &&
              maintenanceCollectionCycleId.isNotEmpty)
            'cycleId': maintenanceCollectionCycleId,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load financial dashboard');
    }
  }

  /// Fetch collection financial years.
  Future<List<Map<String, dynamic>>> getCollectionFinancialYears() async {
    try {
      final res = await _dio.get(
        '/maintenance-management/collection/financial-years',
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final list = data['financialYears'] as List? ?? const [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load financial years');
    }
  }

  /// Fetch collection cycles for a financial year.
  Future<List<Map<String, dynamic>>> getCollectionCyclesForFY(
    String financialYearId,
  ) async {
    try {
      final res = await _dio.get(
        '/maintenance-management/collection/financial-years/$financialYearId/cycles',
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) return [];
      final list = data['cycles'] as List? ?? const [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load collection cycles');
    }
  }

  /// Send due reminders (bulk).
  Future<Map<String, dynamic>> sendDuesReminders({
    required int month,
    required int year,
    String? maintenanceCollectionCycleId,
  }) async {
    try {
      final res = await _dio.post(
        '/maintenance-management/send-dues-reminders',
        data: {
          'month': month,
          'year': year,
          if (maintenanceCollectionCycleId != null &&
              maintenanceCollectionCycleId.isNotEmpty)
            'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
        },
      );
      final body = res.data;
      return body is Map<String, dynamic> ? body : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send reminders');
    }
  }

  /// Send reminder to a single villa.
  Future<Map<String, dynamic>> sendVillaReminder({
    required String villaId,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.sendVillaReminder,
        data: {'villaId': villaId},
      );
      final body = res.data;
      return body is Map<String, dynamic> ? body : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send reminder');
    }
  }

  /// Record a cash/manual payment for a villa.
  Future<Map<String, dynamic>> markPaidCash({
    required String villaId,
    required int month,
    required int year,
    required double amount,
    String paymentMode = 'CASH',
    String? remarks,
    String? maintenanceCollectionCycleId,
    String? bankAccountId,
    String? idempotencyKey,
  }) async {
    try {
      final res = await _dio.post(
        '/maintenance/payments',
        data: {
          'villaId': villaId,
          'month': month,
          'year': year,
          'amount': amount,
          'paymentMode': paymentMode,
          'paymentDate': DateTime.now().toUtc().toIso8601String(),
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
          if (maintenanceCollectionCycleId != null &&
              maintenanceCollectionCycleId.isNotEmpty)
            'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
          if (bankAccountId != null && bankAccountId.isNotEmpty)
            'bankAccountId': bankAccountId,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotencyKey': idempotencyKey,
        },
      );
      final body = res.data;
      return body is Map<String, dynamic> ? body : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to record payment');
    }
  }

  /// Apply advance credit to a billing cycle for a villa.
  Future<Map<String, dynamic>> applyCredit({
    required String villaId,
    required String maintenanceCollectionCycleId,
  }) async {
    try {
      final res = await _dio.post(
        '/maintenance-management/apply-credit',
        data: {
          'villaId': villaId,
          'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
        },
      );
      final body = res.data;
      return body is Map<String, dynamic> ? body : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to apply credit');
    }
  }
}
