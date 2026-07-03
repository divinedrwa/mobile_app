import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminBillingCycleRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getCycles() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminBillingCycles,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load billing cycles');
    }
  }

  Future<Map<String, dynamic>> publishCycle(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminBillingCyclePublish(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to publish cycle');
    }
  }

  Future<Map<String, dynamic>> unpublishCycle(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminBillingCycleUnpublish(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to unpublish cycle');
    }
  }

  Future<Map<String, dynamic>> reopenCycle(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminBillingCycleReopen(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to reopen cycle');
    }
  }
}
