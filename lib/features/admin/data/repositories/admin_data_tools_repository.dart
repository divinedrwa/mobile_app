import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminDataToolsRepository {
  Dio get _dio => DioClient.dio;

  /// Import villas from CSV file bytes.
  Future<Map<String, dynamic>> importVillasCsv(
      Uint8List bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.importVillasCsv,
        data: formData,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to import villas CSV');
    }
  }

  /// Import residents from CSV file bytes.
  Future<Map<String, dynamic>> importResidentsCsv(
      Uint8List bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.importResidentsCsv,
        data: formData,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to import residents CSV');
    }
  }

  /// Export villas as CSV (returns raw bytes).
  Future<Uint8List> exportVillasCsv() async {
    try {
      final res = await _dio.get<ResponseBody>(
        ApiEndpoints.exportVillasCsv,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data as List<int>);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to export villas CSV');
    }
  }

  /// Export residents as CSV (returns raw bytes).
  Future<Uint8List> exportResidentsCsv() async {
    try {
      final res = await _dio.get<ResponseBody>(
        ApiEndpoints.exportResidentsCsv,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data as List<int>);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to export residents CSV');
    }
  }
}
