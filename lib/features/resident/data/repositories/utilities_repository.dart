import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/water_supply_model.dart';
import '../models/water_request_model.dart';
import '../models/garbage_collection_model.dart';

class UtilitiesRepository {
  final DioClient _dioClient;
  UtilitiesRepository(this._dioClient);

  Future<List<WaterSupplyStatus>> getWaterSupplyStatus() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.waterSupplyStatus);
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['gates'] as List? ?? map['status'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return WaterSupplyStatus.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch water supply status');
    }
  }

  Future<List<WaterSupplyEvent>> getWaterSupplyEvents({int limit = 20}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.waterSupplyEvents,
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['events'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return WaterSupplyEvent.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch water supply events');
    }
  }

  Future<GarbageCollectionStatus?> getGarbageCollectionActive() async {
    try {
      final response =
          await _dioClient.get(ApiEndpoints.garbageCollectionActive);
      final data = response.data;
      if (data is! Map) return null;
      return GarbageCollectionStatus.fromJson(
          Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch garbage collection status');
    }
  }

  Future<List<GarbageCollectionEvent>> getGarbageCollectionHistory() async {
    try {
      final response =
          await _dioClient.get(ApiEndpoints.garbageCollectionHistory);
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['events'] as List? ?? map['history'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return GarbageCollectionEvent.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch garbage collection history');
    }
  }

  Future<WaterRequestModel> submitWaterRequest({
    required String gateId,
    required String requestType,
    required String reason,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.waterSupplyRequests,
        data: {
          'gateId': gateId,
          'requestType': requestType,
          'reason': reason,
        },
      );
      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      return WaterRequestModel.fromJson(
        Map<String, dynamic>.from(map['request'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to submit water request');
    }
  }

  Future<List<WaterRequestModel>> getMyWaterRequests() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.waterSupplyRequests);
      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final list = map['requests'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return WaterRequestModel.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch water requests');
    }
  }
}
