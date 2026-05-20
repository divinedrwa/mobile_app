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
}
