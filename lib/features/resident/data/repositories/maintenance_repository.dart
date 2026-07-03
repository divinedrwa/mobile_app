import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../shared/utils/persistent_list_cache.dart';
import '../models/billing_cycle_current_model.dart';
import '../models/maintenance_due_model.dart';
import '../utils/gateway_payment_status.dart';

/// Persistent cache name for the resident's pending maintenance dues list.
const _pendingMaintenanceCacheName = 'pending_maintenance';

/// Cold-start seed for pending maintenance dues, re-parsed from the raw cached
/// API rows through [MaintenanceDueModel.fromJson] (full fidelity). Returns
/// `null` on missing/corrupt entry so callers fall through to the network.
List<MaintenanceDueModel>? readPendingMaintenanceSeed() {
  final key = PersistentListCache.scopedKey(_pendingMaintenanceCacheName);
  if (key == null) return null;
  return PersistentListCache.read<List<MaintenanceDueModel>>(key, (json) {
    return (json as List)
        .whereType<Map>()
        .map((e) => MaintenanceDueModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  });
}

class MaintenanceRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getFinancialDashboard({
    required int month,
    required int year,
    String? maintenanceCollectionCycleId,
    String? billingCycleId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.maintenanceDashboard,
        queryParameters: {
          'month': month,
          'year': year,
          if (maintenanceCollectionCycleId != null &&
              maintenanceCollectionCycleId.isNotEmpty)
            'cycleId': maintenanceCollectionCycleId,
          if (billingCycleId != null && billingCycleId.isNotEmpty)
            'billingCycleId': billingCycleId,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch maintenance dashboard');
    }
  }

  /// Sends due-reminder notifications for the given period. Returns the
  /// raw response body so callers can surface counters like
  /// `{ notified: 7 }` in toasts.
  Future<Map<String, dynamic>> sendDuesReminders({
    required int month,
    required int year,
    String? maintenanceCollectionCycleId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.sendDuesReminders,
        data: {
          'month': month,
          'year': year,
          if (maintenanceCollectionCycleId != null &&
              maintenanceCollectionCycleId.isNotEmpty)
            'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
        },
      );
      final body = response.data;
      return body is Map<String, dynamic>
          ? body
          : <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send due reminders');
    }
  }

  /// Records a cash payment against a villa for the given month/year. Maps
  /// to the admin-only `POST /maintenance-management/mark-paid` endpoint —
  /// the same one the web admin uses, so behavior (snapshot + cash ledger
  /// reconciliation via the credit walker) stays consistent.
  Future<Map<String, dynamic>> markPaidCash({
    required String villaId,
    required int month,
    required int year,
    required double amount,
    String paymentMode = 'CASH',
    String? remarks,
    String? maintenanceCollectionCycleId,
    String? bankAccountId,
    bool applyCredit = false,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.maintenanceMarkPaid,
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
      final body = response.data;
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to record cash payment');
    }
  }

  /// Applies advance credit from prior overpayments to a billing cycle.
  Future<Map<String, dynamic>> applyCredit({
    required String villaId,
    required String maintenanceCollectionCycleId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.applyCredit,
        data: {
          'villaId': villaId,
          'maintenanceCollectionCycleId': maintenanceCollectionCycleId,
        },
      );
      final body = response.data;
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to apply advance credit');
    }
  }

  /// Downloads an individual payment receipt PDF for a billing cycle.
  Future<List<int>> downloadPaymentReceiptPdf({
    required String cycleId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiEndpoints.paymentReceiptPdf,
        queryParameters: {'cycleId': cycleId},
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to download payment receipt');
    }
  }

  Future<List<int>> downloadMaintenanceReportPdf({
    required int month,
    required int year,
    String? maintenanceCollectionCycleId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiEndpoints.maintenanceDashboardReportPdf,
        queryParameters: {
          'month': month,
          'year': year,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to download maintenance report');
    }
  }

  Future<Map<String, dynamic>> getOutstandingDues() async {
    try {
      final response = await _dio.get(ApiEndpoints.outstandingDues);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch outstanding dues');
    }
  }

  Future<Map<String, dynamic>> sendVillaReminder({
    required String villaId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.sendVillaReminder,
        data: {'villaId': villaId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to send reminder');
    }
  }

  Future<List<MaintenanceDueModel>> getPendingMaintenance() async {
    try {
      final response = await _dio.get(ApiEndpoints.maintenancePending);
      final data = response.data;
      final list = data is Map<String, dynamic>
          ? (data['pending'] as List? ?? const [])
          : const [];
      final rows = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final key = PersistentListCache.scopedKey(_pendingMaintenanceCacheName);
      if (key != null) {
        await PersistentListCache.write(key, rows);
      }
      return rows.map(MaintenanceDueModel.fromJson).toList();
    } on DioException catch (e) {
      // 404 "Villa not assigned" — not an error, just no dues to show.
      if (e.response?.statusCode == 404) return [];
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

  /// Society Financial years (`GET /v1/financial-years`) — same source as admin billing UI.
  Future<List<Map<String, dynamic>>> getBillingFinancialYears() async {
    try {
      final response = await _dio.get(ApiEndpoints.billingFinancialYears);
      final data = response.data;
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

  /// Single cycle context for deep links (`GET /v1/billing-cycles/context`).
  Future<Map<String, dynamic>?> getBillingCycleContext(String billingCycleId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.billingCycleContext,
        queryParameters: {'billingCycleId': billingCycleId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw mapDioException(e, 'Failed to resolve billing cycle');
    }
  }

  /// Billing cycles created for a financial year (`GET /v1/billing-cycles`).
  Future<Map<String, dynamic>> getBillingCyclesForFinancialYear(
    String financialYearId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.billingCyclesForYear,
        queryParameters: {'financialYearId': financialYearId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load billing cycles');
    }
  }

  Future<BillingCycleCurrent> getCurrentBillingCycle(
    String societyId, {
    String? billingCycleId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.billingCyclesCurrent(
          societyId: societyId,
          billingCycleId: billingCycleId,
        ),
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

  /// Initiate a PhonePe payment. Returns { redirectUrl, merchantTransactionId, paymentId, totalDue }.
  Future<Map<String, dynamic>> initiatePhonePePayment({
    String? cycleId,
    bool payAllPending = false,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.phonePeInitiate,
        data: {
          if (payAllPending) 'payAllPending': true,
          if (!payAllPending && cycleId != null && cycleId.isNotEmpty)
            'cycleId': cycleId,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotencyKey': idempotencyKey,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not start PhonePe payment');
    }
  }

  /// Poll PhonePe payment status (structured; never returns an empty map).
  Future<GatewayPaymentPollResult> checkPhonePeStatus(String txnId) async {
    try {
      final response = await _dio.get(ApiEndpoints.phonePeStatus(txnId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return GatewayPaymentPollResult.fromJson(data);
      }
      return GatewayPaymentPollResult.empty();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to check PhonePe payment status');
    }
  }

  /// Poll Razorpay order status and reconcile on server when captured.
  Future<GatewayPaymentPollResult> checkRazorpayStatus(String orderId) async {
    try {
      final response = await _dio.get(ApiEndpoints.razorpayStatus(orderId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return GatewayPaymentPollResult.fromJson(data);
      }
      return GatewayPaymentPollResult.empty();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to verify Razorpay payment');
    }
  }

  /// Creates a Razorpay order on the server. Completing payment still requires gateway capture + webhook.
  Future<Map<String, dynamic>> createBillingOrder({
    String? cycleId,
    bool payAllPending = false,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.billingCreateOrder,
        data: {
          if (payAllPending) 'payAllPending': true,
          if (!payAllPending && cycleId != null && cycleId.isNotEmpty)
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
    String? idempotencyKey,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.maintenancePayments,
        data: {
          'villaId': villaId,
          'month': month,
          'year': year,
          'amount': amount,
          'paymentDate': DateTime.now().toUtc().toIso8601String(),
          'paymentMode': paymentMode,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotencyKey': idempotencyKey,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to process payment');
    }
  }
}
