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
}
