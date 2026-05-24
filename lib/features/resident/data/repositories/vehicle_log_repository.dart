import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/vehicle_log_model.dart';

class VehicleLogRepository {
  final DioClient _dioClient;
  VehicleLogRepository(this._dioClient);

  Future<List<VehicleLogEntry>> getMyVehicleLog() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.myVehicleLog);
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['entries'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return VehicleLogEntry.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch vehicle log');
    }
  }
}
