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
  }) async {
    try {
      // Backend derives the cycle from month/year — no cycle id needed.
      final res = await _dio.post(
        '/maintenance-management/send-dues-reminders',
        data: {
          'month': month,
          'year': year,
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
    String? bankAccountId,
    String? idempotencyKey,
  }) async {
    try {
      // Payment is keyed by villa/month/year; the cycle id is derived
      // server-side and isn't part of this endpoint's contract.
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

  /// Manual credit adjustment (add or deduct) for a villa in a cycle.
  Future<Map<String, dynamic>> manualCreditAdjustment({
    required String villaId,
    required String maintenanceCollectionCycleId,
    required double amount,
    required String type,
    String? remarks,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.maintenanceManualCreditAdjustment,
        data: {
          'villaId': villaId,
          'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
          'amount': amount,
          'type': type,
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        },
      );
      final body = res.data;
      return body is Map<String, dynamic> ? body : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to adjust credit');
    }
  }

  /// Edit villa grid row (expected / paid amounts) for a cycle.
  Future<Map<String, dynamic>> editVillaGridRow({
    required String cycleId,
    required String villaId,
    double? expectedAmount,
    double? paidAmount,
  }) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.maintenanceVillaGridRow(cycleId),
        data: {
          'villaId': villaId,
          if (expectedAmount != null) 'expectedAmount': expectedAmount,
          if (paidAmount != null) 'paidAmount': paidAmount,
        },
      );
      final body = res.data;
      return body is Map<String, dynamic> ? body : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update villa row');
    }
  }

  /// Get outstanding dues across all billing cycles.
  Future<Map<String, dynamic>> getOutstandingDues() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.maintenanceOutstandingDues,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load outstanding dues');
    }
  }

  /// Get payment history for a single villa.
  Future<Map<String, dynamic>> getVillaHistory(String villaId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.maintenanceVillaHistory(villaId),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load villa history');
    }
  }
}
