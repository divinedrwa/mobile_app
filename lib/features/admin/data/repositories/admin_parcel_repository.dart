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
