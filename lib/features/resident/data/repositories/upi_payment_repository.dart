import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/upi_payment_model.dart';

class UpiPaymentRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch society UPI config (VPA + payee name).
  Future<Map<String, dynamic>> getUpiConfig() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.upiConfig);
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load UPI config');
    }
  }

  /// Submit a UPI payment claim.
  Future<Map<String, dynamic>> submitUpiPayment({
    required double amount,
    required int month,
    required int year,
    String? upiTransactionRef,
    String? cycleId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.upiPaymentSubmit,
        data: {
          'amount': amount,
          'month': month,
          'year': year,
          if (upiTransactionRef != null && upiTransactionRef.isNotEmpty)
            'upiTransactionRef': upiTransactionRef,
          if (cycleId != null && cycleId.isNotEmpty) 'cycleId': cycleId,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to submit UPI payment');
    }
  }

  /// Fetch the resident's own UPI payment submissions.
  Future<List<UpiPaymentModel>> getMyUpiPayments() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.myUpiPayments);
      final list = res.data?['submissions'] as List? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => UpiPaymentModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load UPI payments');
    }
  }
}
