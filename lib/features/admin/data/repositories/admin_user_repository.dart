import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../shared/models/user_model.dart';

class AdminUserRepository {
  Dio get _dio => DioClient.dio;

  /// List all society users, optionally filtered by role or active status.
  Future<List<UserModel>> getUsers({String? role, bool? isActive}) async {
    try {
      final params = <String, dynamic>{};
      if (role != null) params['role'] = role;
      if (isActive != null) params['isActive'] = isActive.toString();

      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminUsers,
        queryParameters: params,
      );
      final data = res.data;
      if (data == null) return [];
      final raw = data['users'] as List<dynamic>? ?? [];
      return raw
          .map((e) =>
              UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load users');
    }
  }

  /// Update a user's role.
  Future<void> updateUserRole(String userId, {required String role}) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminUserById(userId),
        data: {'role': role},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update user role');
    }
  }

  /// Create a new society user (admin, guard, or resident).
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? villaId,
    String? villaNumber,
    String? unitId,
    String? residentType,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminUsers,
        data: {
          'username': username,
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (villaId != null && villaId.isNotEmpty) 'villaId': villaId,
          if (villaNumber != null && villaNumber.isNotEmpty)
            'villaNumber': villaNumber,
          if (unitId != null && unitId.isNotEmpty) 'unitId': unitId,
          if (residentType != null && residentType.isNotEmpty)
            'residentType': residentType,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create user');
    }
  }

  /// Hard-deletes a user via DELETE /users/:id (not a deactivation).
  Future<void> deleteUser(String userId) async {
    try {
      await _dio.delete(ApiEndpoints.adminUserById(userId));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete user');
    }
  }
}
