import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminBannerRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminBannersList);
      final data = res.data;
      if (data is Map) {
        final list = data['banners'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load banners');
    }
  }

  Future<Map<String, dynamic>> createBanner({
    required String title,
    String? description,
    String? imageUrl,
    String type = 'ANNOUNCEMENT',
    bool isActive = true,
    int priority = 0,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminBannersList,
        data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          'type': type,
          'isActive': isActive,
          'priority': priority,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create banner');
    }
  }

  Future<Map<String, dynamic>> updateBanner(
    String id, {
    String? title,
    String? description,
    String? imageUrl,
    String? type,
    bool? isActive,
    int? priority,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.adminBannerById(id),
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (type != null) 'type': type,
          if (isActive != null) 'isActive': isActive,
          if (priority != null) 'priority': priority,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update banner');
    }
  }

  Future<void> deleteBanner(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminBannerById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete banner');
    }
  }
}
