import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/network/dio_client.dart';
import '../models/security_contact_model.dart';
import 'package:dio/dio.dart';

class SecurityContactRepository {
  Future<List<SecurityContactModel>> getSecurityContacts() async {
    try {
      final response = await DioClient.dio.get(ApiEndpoints.residentSecurityContacts);
      final data = response.data;
      if (data is! Map) return const [];
      final rawList = data['contacts'];
      if (rawList is! List) return const [];
      return rawList
          .whereType<Map>()
          .map((e) => SecurityContactModel.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.phone.trim().isNotEmpty)
          .toList();
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is AppException) throw wrapped;
      throw AppException(
        message: parseApiErrorMessage(e.response?.data, 'Could not load security contacts'),
      );
    }
  }
}
