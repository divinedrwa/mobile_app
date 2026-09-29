import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminBillingCyclesRepository {
  Dio get _dio => DioClient.dio;

  /// Get all billing cycles for the society (published and drafts).
  Future<List<Map<String, dynamic>>> getCycles({
    bool? published,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.maintenanceManagement}/cycles',
        queryParameters: {
          if (published != null) 'published': published,
          'limit': limit,
        },
      );
      final list = res.data?['cycles'] as List? ?? [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load billing cycles');
    }
  }

  /// Get a single billing cycle with full details.
  Future<Map<String, dynamic>> getCycle(String cycleId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.maintenanceManagement}/cycles/$cycleId',
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load billing cycle');
    }
  }

  /// Create a new billing cycle.
  Future<void> createCycle({
    required int periodMonth,
    required int periodYear,
    required double maintenanceAmount,
    String? maintenanceBillingMode,
    double? maintenanceSqftRate,
    String? description,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/cycles',
        data: {
          'periodMonth': periodMonth,
          'periodYear': periodYear,
          'maintenanceAmount': maintenanceAmount,
          if (maintenanceBillingMode != null)
            'maintenanceBillingMode': maintenanceBillingMode,
          if (maintenanceSqftRate != null) 'maintenanceSqftRate': maintenanceSqftRate,
          if (description != null) 'description': description,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create billing cycle');
    }
  }

  /// Update billing cycle. Only provided fields are updated.
  Future<void> updateCycle(
    String cycleId, {
    String? description,
    double? maintenanceAmount,
    String? maintenanceBillingMode,
    double? maintenanceSqftRate,
  }) async {
    try {
      await _dio.put(
        '${ApiEndpoints.maintenanceManagement}/cycles/$cycleId',
        data: {
          if (description != null) 'description': description,
          if (maintenanceAmount != null) 'maintenanceAmount': maintenanceAmount,
          if (maintenanceBillingMode != null)
            'maintenanceBillingMode': maintenanceBillingMode,
          if (maintenanceSqftRate != null) 'maintenanceSqftRate': maintenanceSqftRate,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update billing cycle');
    }
  }

  /// Delete a draft billing cycle.
  Future<void> deleteCycle(String cycleId) async {
    try {
      await _dio.delete('${ApiEndpoints.maintenanceManagement}/cycles/$cycleId');
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete billing cycle');
    }
  }

  /// Publish a draft cycle to make it live.
  Future<void> publishCycle(String cycleId) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/cycles/$cycleId/publish',
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to publish billing cycle');
    }
  }

  /// Waive late fees for a villa in a cycle.
  Future<void> waiveLateFees({
    required String villaId,
    required String cycleId,
    String? reason,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/waive-late-fees',
        data: {
          'villaId': villaId,
          'cycleId': cycleId,
          if (reason != null) 'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to waive late fees');
    }
  }

  /// Record a cash payment outside the digital system.
  Future<void> recordCashPayment({
    required String villaId,
    required String cycleId,
    required double amount,
    required DateTime paymentDate,
    String? receiptNumber,
    String? notes,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/cash-payment',
        data: {
          'villaId': villaId,
          'cycleId': cycleId,
          'amount': amount,
          'paymentDate': paymentDate.toIso8601String(),
          if (receiptNumber != null) 'receiptNumber': receiptNumber,
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to record cash payment');
    }
  }

  /// Get financial years for the society.
  Future<List<Map<String, dynamic>>> getFinancialYears() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.maintenanceManagement}/financial-years',
      );
      final list = res.data?['financialYears'] as List? ?? [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load financial years');
    }
  }

  /// Create a financial year.
  Future<void> createFinancialYear({
    required String label,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/financial-years',
        data: {
          'label': label,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create financial year');
    }
  }
}
