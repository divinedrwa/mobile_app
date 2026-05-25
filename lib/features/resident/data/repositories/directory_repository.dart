import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/directory_resident_model.dart';

class DirectoryRepository {
  final DioClient _dioClient;
  DirectoryRepository(this._dioClient);

  Future<List<DirectoryResident>> searchDirectory({String? query}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.communityDirectory,
        queryParameters:
            query != null && query.isNotEmpty ? {'q': query} : null,
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['residents'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return DirectoryResident.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch community directory');
    }
  }

  /// Paginated directory search
  Future<({List<DirectoryResident> items, int total, bool hasMore})>
      searchDirectoryPaginated({
    String? query,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.communityDirectory,
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['residents'] as List? ?? [];
      final items = list.whereType<Map>().map((raw) {
        return DirectoryResident.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
      final total = (map['total'] as num?)?.toInt() ?? items.length;
      final hasMore =
          map['hasMore'] as bool? ?? (offset + items.length < total);
      return (items: items, total: total, hasMore: hasMore);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch community directory');
    }
  }
}
