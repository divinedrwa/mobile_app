import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminDocumentRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getDocuments({
    String? search,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': 200,
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
      };
      final res = await _dio.get(
        ApiEndpoints.adminDocuments,
        queryParameters: params,
      );
      final data = res.data;
      if (data is Map) {
        final list = data['documents'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load documents');
    }
  }

  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String fileUrl,
    required String category,
    String? description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminDocuments,
        data: {
          'title': title,
          'fileUrl': fileUrl,
          'category': category,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create document');
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminDocumentById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete document');
    }
  }
}
