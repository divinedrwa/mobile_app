import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../resident/data/models/upi_payment_model.dart';

class AdminUpiPaymentRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch UPI submissions filtered by status (default: PENDING).
  Future<List<UpiPaymentModel>> getSubmissions({String status = 'PENDING'}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminUpiPaymentsPending,
        queryParameters: {'status': status},
      );
      final list = res.data?['submissions'] as List? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => UpiPaymentModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load UPI submissions');
    }
  }

  /// Verify (approve) a UPI submission.
  Future<Map<String, dynamic>> verifySubmission(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminUpiVerify(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to verify UPI payment');
    }
  }

  /// Reject a UPI submission with a reason.
  Future<Map<String, dynamic>> rejectSubmission(
      String id, String reason) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminUpiReject(id),
        data: {'rejectionReason': reason},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to reject UPI payment');
    }
  }

  /// Get UPI stats (pending / verified / rejected counts).
  Future<Map<String, dynamic>> getStats() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.adminUpiStats);
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load UPI stats');
    }
  }
}
