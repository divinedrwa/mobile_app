import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/family_member_model.dart';

/// Repository for family member operations
class FamilyMemberRepository {
  Dio get _dio => DioClient.dio;

  /// Get all family members
  Future<List<FamilyMemberModel>> getFamilyMembers() async {
    try {
      final response = await _dio.get(ApiEndpoints.familyMembers);
      
      // Backend returns { "familyMembers": [...], "count": 0 }
      final membersList = response.data['familyMembers'] as List? ?? [];
      
      return membersList
          .map((json) => FamilyMemberModel.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch family members');
    }
  }

  /// Add family member
  Future<FamilyMemberModel> addFamilyMember({
    required String name,
    required String relationship,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    String? photo,
    bool canApproveVisitors = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.addFamilyMember,
        data: {
          'name': name,
          'relationship': relationship,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
          if (photo != null) 'photo': photo,
          'canApproveVisitors': canApproveVisitors,
        },
      );

      return FamilyMemberModel.fromJson(response.data['familyMember']);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to add family member');
    }
  }

  /// Update family member
  Future<FamilyMemberModel> updateFamilyMember({
    required String id,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    String? photo,
    bool? canApproveVisitors,
  }) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.updateFamilyMember(id),
        data: {
          if (name != null) 'name': name,
          if (relationship != null) 'relationship': relationship,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
          if (photo != null) 'photo': photo,
          if (canApproveVisitors != null)
            'canApproveVisitors': canApproveVisitors,
        },
      );

      return FamilyMemberModel.fromJson(response.data['familyMember']);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update family member');
    }
  }

  /// Delete family member
  Future<void> deleteFamilyMember(String id) async {
    try {
      await _dio.delete(ApiEndpoints.deleteFamilyMember(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete family member');
    }
  }
}
