import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminStaffRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all staff (admin sees all society staff).
  Future<List<Map<String, dynamic>>> getStaff() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminStaff,
      );
      final list = res.data?['staff'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load staff');
    }
  }

  /// Fetch staff detail by id.
  Future<Map<String, dynamic>> getStaffById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminStaffById(id),
      );
      return res.data?['staff'] as Map<String, dynamic>? ?? res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load staff details');
    }
  }

  /// Create a new staff member.
  Future<void> createStaff({
    required String name,
    required String type,
    required String phone,
    List<String>? villaIds,
    String? address,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminStaff,
        data: {
          'name': name,
          'type': type,
          'phone': phone,
          if (villaIds != null && villaIds.isNotEmpty) 'villaIds': villaIds,
          if (address != null && address.isNotEmpty) 'address': address,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create staff');
    }
  }

  /// Update a staff member.
  Future<void> updateStaff(
    String id, {
    String? name,
    String? type,
    String? phone,
    String? address,
    bool? isActive,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminStaffById(id),
        data: {
          if (name != null) 'name': name,
          if (type != null) 'type': type,
          if (phone != null) 'phone': phone,
          if (address != null) 'address': address,
          if (isActive != null) 'isActive': isActive,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update staff');
    }
  }

  /// Deactivate a staff member (soft delete).
  Future<void> deactivateStaff(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminStaffById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to deactivate staff');
    }
  }
}
