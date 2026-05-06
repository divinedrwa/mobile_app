import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/vendor_model.dart';

class VendorRepository {
  Dio get _dio => DioClient.dio;

  Future<List<VendorModel>> getVendors() async {
    try {
      final response = await _dio.get(ApiEndpoints.vendors);
      final list = response.data['vendors'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((raw) => VendorModel.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch vendors');
    }
  }
}
