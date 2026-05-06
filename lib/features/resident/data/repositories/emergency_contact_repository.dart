import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactRepository {
  Dio get _dio => DioClient.dio;

  Future<List<EmergencyContactModel>> getContacts() async {
    try {
      final response = await _dio.get(ApiEndpoints.emergencyContacts);
      final list = response.data['contacts'] as List? ?? [];
      return list
          .whereType<Map>()
          .map(
            (e) => EmergencyContactModel.fromJson({
              ...Map<String, dynamic>.from(e),
              'relationship': e['relationship'] ?? e['relation'],
            }),
          )
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch emergency contacts');
    }
  }

  Future<void> addContact({
    required String name,
    required String relationship,
    required String phone,
    String? address,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.emergencyContacts,
        data: {
          'name': name,
          'relationship': relationship,
          'phone': phone,
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to add emergency contact');
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await _dio.delete(ApiEndpoints.deleteEmergencyContact(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete emergency contact');
    }
  }
}
