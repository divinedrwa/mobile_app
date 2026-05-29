import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/parcel_model.dart';

/// Repository for parcel operations
class ParcelRepository {
  Dio get _dio => DioClient.dio;

  /// Get all parcels
  Future<List<ParcelModel>> getParcels() async {
    try {
      final response = await _dio.get(ApiEndpoints.myParcels);

      // Backend returns { "parcels": [...] } or direct array
      final parcelsList = response.data is List
          ? response.data as List
          : (response.data['parcels'] as List? ?? []);

      return parcelsList
          .map((json) => ParcelModel.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch parcels');
    }
  }

  /// Get pending parcels only
  Future<List<ParcelModel>> getPendingParcels() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.myParcels,
        queryParameters: {'status': 'PENDING'},
      );

      final parcelsList = response.data is List
          ? response.data as List
          : (response.data['parcels'] as List? ?? []);

      return parcelsList
          .map((json) => ParcelModel.fromJson(json))
          .where((parcel) => parcel.status == ParcelStatus.pending)
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch pending parcels');
    }
  }

  /// Mark parcel as collected
  Future<ParcelModel> markAsCollected(String parcelId) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.parcelCollect(parcelId),
      );

      return ParcelModel.fromJson(response.data['parcel']);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to mark parcel as collected');
    }
  }

  /// Get parcel history — same endpoint, backend returns most recent parcels.
  Future<List<ParcelModel>> getParcelHistory() async {
    try {
      final response = await _dio.get(ApiEndpoints.myParcels);

      final parcelsList = response.data is List
          ? response.data as List
          : (response.data['parcels'] as List? ?? []);

      return parcelsList
          .map((json) => ParcelModel.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch parcel history');
    }
  }
}
