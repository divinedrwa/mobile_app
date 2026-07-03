import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminVisitorRepository {
  Dio get _dio => DioClient.dio;

  Future<Map<String, dynamic>> getVisitors({
    String? search,
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminVisitors,
        queryParameters: params,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load visitors');
    }
  }

}
