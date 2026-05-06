import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/daily_help_model.dart';

class DailyHelpRepository {
  Dio get _dio => DioClient.dio;

  Future<List<DailyHelpModel>> getDailyHelp() async {
    try {
      final response = await _dio.get('/residents/my-staff');
      final list = response.data['staff'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        final json = Map<String, dynamic>.from(raw);
        return DailyHelpModel.fromJson({
          'id': json['id'],
          'assignmentId': json['assignmentId'],
          'name': json['name'],
          'type': _typeToLabel(json['type']?.toString()),
          'phone': json['phone'],
          'timings': json['notes'],
          'isActive': json['isActive'] ?? true,
        });
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch daily help');
    }
  }

  Future<void> addDailyHelp({
    required String name,
    required String type,
    required String phone,
    String? address,
  }) async {
    try {
      await _dio.post(
        '/residents/add-staff',
        data: {
          'name': name,
          'type': _labelToType(type),
          'phone': phone,
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to add daily help');
    }
  }

  Future<void> removeDailyHelp(String assignmentId) async {
    try {
      await _dio.delete('/residents/staff/$assignmentId');
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to remove daily help');
    }
  }

  String _typeToLabel(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'MAID':
        return 'Maid';
      case 'COOK':
        return 'Cook';
      case 'DRIVER':
        return 'Driver';
      case 'GARDENER':
        return 'Gardener';
      case 'SECURITY':
        return 'Security';
      default:
        return 'Other';
    }
  }

  String _labelToType(String label) {
    switch (label.toLowerCase()) {
      case 'maid':
        return 'MAID';
      case 'cook':
        return 'COOK';
      case 'driver':
        return 'DRIVER';
      case 'gardener':
        return 'GARDENER';
      case 'security':
        return 'SECURITY';
      default:
        return 'OTHER';
    }
  }
}
