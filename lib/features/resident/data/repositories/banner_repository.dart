import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/banner_model.dart';

class BannerRepository {
  final DioClient _dioClient;
  BannerRepository(this._dioClient);

  Future<List<BannerModel>> getActiveBanners() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.banners);
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final list = map['banners'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        return BannerModel.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch banners');
    }
  }
}
