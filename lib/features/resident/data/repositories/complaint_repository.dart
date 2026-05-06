import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/complaint_list_item.dart';

class ComplaintRepository {
  Dio get _dio => DioClient.dio;

  Future<List<ComplaintListItem>> getMyComplaints({String? status}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.myComplaints,
        queryParameters: status != null ? {'status': status} : null,
      );
      final data = res.data;
      if (data == null) return [];
      final raw = data['complaints'] as List<dynamic>?;
      if (raw == null) return [];
      return raw
          .map(
            (e) => ComplaintListItem.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load complaints');
    }
  }

  Future<void> submitComplaint({
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.createComplaint,
        data: {
          'title': title,
          'description': description,
          'category': category,
          'priority': priority,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to submit complaint');
    }
  }
}
