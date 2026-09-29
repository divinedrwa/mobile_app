import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminMaintenanceHubRepository {
  Dio get _dio => DioClient.dio;

  /// Mark maintenance bill as paid for a villa in a cycle.
  /// [maintenanceCollectionCycleId] is optional; if not provided, backend auto-resolves.
  Future<void> markPaid({
    required String villaId,
    required int month,
    required int year,
    required double amount,
    String? paymentMode,
    String? paymentRef,
    String? receiptNumber,
    String? maintenanceCollectionCycleId,
    String? idempotencyKey,
    String? notes,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/mark-paid',
        data: {
          'villaId': villaId,
          'month': month,
          'year': year,
          'amount': amount,
          if (paymentMode != null) 'paymentMode': paymentMode,
          if (paymentRef != null) 'paymentRef': paymentRef,
          if (receiptNumber != null) 'receiptNumber': receiptNumber,
          if (maintenanceCollectionCycleId != null)
            'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to record payment');
    }
  }

  /// Reverse all payments for a villa in a billing cycle.
  Future<Map<String, dynamic>> reversePayment({
    required String villaId,
    required String maintenanceCollectionCycleId,
    String? reason,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.maintenanceManagement}/reverse-payment',
        data: {
          'villaId': villaId,
          'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
          if (reason != null) 'reason': reason,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to reverse payment');
    }
  }

  /// Record an additional fund (custom amount):
  /// destination: MERGE_WITH_MAINTENANCE or KEEP_SEPARATE.
  Future<void> createAdditionalFund({
    required String title,
    required double amount,
    required DateTime receivedDate,
    required String destination,
    String? source,
    String? notes,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.maintenanceManagement}/additional-funds',
        data: {
          'title': title,
          'amount': amount,
          'receivedDate': receivedDate.toIso8601String(),
          'destination': destination,
          if (source != null) 'source': source,
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to record additional fund');
    }
  }

  /// Update additional fund. Only provided fields are updated.
  Future<void> updateAdditionalFund(
    String id, {
    String? title,
    double? amount,
    DateTime? receivedDate,
    String? destination,
    String? source,
    String? notes,
  }) async {
    try {
      await _dio.put(
        '${ApiEndpoints.maintenanceManagement}/additional-funds/$id',
        data: {
          if (title != null) 'title': title,
          if (amount != null) 'amount': amount,
          if (receivedDate != null) 'receivedDate': receivedDate.toIso8601String(),
          if (destination != null) 'destination': destination,
          if (source != null) 'source': source,
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update additional fund');
    }
  }

  /// Delete an additional fund.
  Future<void> deleteAdditionalFund(String id) async {
    try {
      await _dio.delete(
        '${ApiEndpoints.maintenanceManagement}/additional-funds/$id',
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete additional fund');
    }
  }

  /// Get outstanding dues for a villa (all unpaid bills across cycles).
  Future<Map<String, dynamic>> getOutstandingDues({
    required String villaId,
    int limit = 100,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.maintenanceManagement}/outstanding-dues/$villaId',
        queryParameters: {'limit': limit},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load outstanding dues');
    }
  }

  /// Get billing cycles for a society.
  Future<List<Map<String, dynamic>>> getBillingCycles({
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
}
