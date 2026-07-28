import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminPaymentDisputesRepository {
  Dio get _dio => DioClient.dio;

  Future<({List<Map<String, dynamic>> disputes, int openCount})> getDisputes({
    String? status,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminPaymentDisputes,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final data = res.data ?? {};
      final raw = data['disputes'] as List<dynamic>? ?? [];
      final disputes = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final openCount = (data['openCount'] as num?)?.toInt() ?? 0;
      return (disputes: disputes, openCount: openCount);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load payment disputes');
    }
  }

  Future<void> updateDispute(
    String id, {
    required String status,
    String? adminNote,
  }) async {
    try {
      await _dio.patch(
        '${ApiEndpoints.adminPaymentDisputes}/$id',
        data: {
          'status': status,
          if (adminNote != null && adminNote.trim().isNotEmpty)
            'adminNote': adminNote.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update dispute');
    }
  }
}
