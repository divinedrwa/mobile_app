import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/payment_method_model.dart';

class PaymentMethodsRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch enabled payment methods for the resident's society.
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/residents/payment-methods');
      final list = res.data?['methods'] as List? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => PaymentMethodModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load payment methods');
    }
  }
}
