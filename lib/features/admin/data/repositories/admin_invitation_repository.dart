import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminInvitationRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all invitations for the society.
  Future<List<Map<String, dynamic>>> getInvitations({
    String? status,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.adminInvitations,
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['invitations'] is List) {
        return (data['invitations'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load invitations');
    }
  }

  /// Create a new invitation.
  Future<Map<String, dynamic>> createInvitation({
    required String role,
    String? email,
    String? phone,
    String? villaId,
    String? expiresAt,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminInvitations,
        data: {
          'role': role,
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (villaId != null && villaId.isNotEmpty) 'villaId': villaId,
          if (expiresAt != null && expiresAt.isNotEmpty) 'expiresAt': expiresAt,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create invitation');
    }
  }

  /// Revoke a pending invitation.
  Future<Map<String, dynamic>> revokeInvitation(String id) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.adminInvitationRevoke(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to revoke invitation');
    }
  }
}
