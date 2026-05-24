import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/incident_model.dart';

class IncidentRepository {
  final DioClient _dioClient;
  IncidentRepository(this._dioClient);

  Future<List<IncidentModel>> getIncidents({int limit = 50}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.incidents,
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['incidents'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return IncidentModel.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch incidents');
    }
  }
}
