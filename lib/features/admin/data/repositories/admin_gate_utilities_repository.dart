import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminGateUtilitiesRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all society gates.
  Future<List<Map<String, dynamic>>> getGates() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminGates,
      );
      final list = res.data?['gates'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load gates');
    }
  }

  /// Get current water supply status for all active gates.
  Future<List<Map<String, dynamic>>> getWaterSupplyStatus() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.waterSupplyStatus,
      );
      final list = res.data?['status'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load water supply status');
    }
  }

  /// Toggle water supply at a gate.
  Future<Map<String, dynamic>> toggleWaterSupply({
    required String gateId,
    required bool turnedOn,
    String? reason,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.waterSupplyToggle,
        data: {
          'gateId': gateId,
          'turnedOn': turnedOn,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to toggle water supply');
    }
  }

  /// Get recent water supply events.
  Future<List<Map<String, dynamic>>> getWaterSupplyEvents({
    String? gateId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.waterSupplyEvents,
        queryParameters: {
          if (gateId != null) 'gateId': gateId,
        },
      );
      final list = res.data?['events'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load water supply events');
    }
  }

  /// Log garbage collector entry at a gate.
  Future<Map<String, dynamic>> logGarbageEntry({
    required String gateId,
    String? notes,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.garbageCollectionEntry,
        data: {
          'gateId': gateId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to log garbage entry');
    }
  }

  /// Mark garbage collector exit.
  Future<void> markGarbageExit(String eventId) async {
    try {
      await _dio.patch(ApiEndpoints.garbageCollectionExit(eventId));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to mark garbage exit');
    }
  }

  /// Check if garbage collector is currently inside.
  Future<Map<String, dynamic>> getGarbageActive({String? gateId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.garbageCollectionActive,
        queryParameters: {
          if (gateId != null) 'gateId': gateId,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to check garbage status');
    }
  }

  /// Get recent garbage collection events.
  Future<List<Map<String, dynamic>>> getGarbageEvents({
    String? gateId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.garbageCollectionEvents,
        queryParameters: {
          if (gateId != null) 'gateId': gateId,
        },
      );
      final list = res.data?['events'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load garbage events');
    }
  }
}
