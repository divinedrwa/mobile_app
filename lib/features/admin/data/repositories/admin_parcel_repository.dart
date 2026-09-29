import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminParcelRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all society parcels (raw map with `parcels` array + `pendingCount`).
  Future<Map<String, dynamic>> getAdminParcels() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminParcels,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load parcels');
    }
  }

  Future<void> createParcel({
    required String villaId,
    required String description,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminParcels,
        data: {'villaId': villaId, 'description': description},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to log parcel');
    }
  }

  Future<void> updateParcel(String id, {required String description}) async {
    try {
      await _dio.put(
        ApiEndpoints.adminParcelById(id),
        data: {'description': description},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update parcel');
    }
  }

  Future<void> deleteParcel(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminParcelById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete parcel');
    }
  }

  /// Update parcel status.
  Future<void> updateParcelStatus(String id, {required String status}) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminParcelStatus(id),
        data: {'status': status},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update parcel status');
    }
  }
}
