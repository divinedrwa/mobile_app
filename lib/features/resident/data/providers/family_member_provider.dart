import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/family_member_model.dart';
import '../repositories/family_member_repository.dart';

/// Family Member State Notifier
class FamilyMemberNotifier extends StateNotifier<AsyncValue<List<FamilyMemberModel>>> {
  final FamilyMemberRepository _repository;

  FamilyMemberNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchFamilyMembers();
  }

  /// Fetch all family members
  Future<void> fetchFamilyMembers() async {
    state = const AsyncValue.loading();
    try {
      final members = await _repository.getFamilyMembers();
      state = AsyncValue.data(members);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add family member
  Future<bool> addFamilyMember({
    required String name,
    required String relationship,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
  }) async {
    try {
      await _repository.addFamilyMember(
        name: name,
        relationship: relationship,
        phone: phone,
        email: email,
        dateOfBirth: dateOfBirth,
      );
      await fetchFamilyMembers(); // Refresh list
      return true;
    } catch (e) {
      debugPrint('Error adding family member: $e');
      return false;
    }
  }

  /// Update family member
  Future<bool> updateFamilyMember({
    required String id,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
  }) async {
    try {
      await _repository.updateFamilyMember(
        id: id,
        name: name,
        relationship: relationship,
        phone: phone,
        email: email,
        dateOfBirth: dateOfBirth,
      );
      await fetchFamilyMembers(); // Refresh list
      return true;
    } catch (e) {
      debugPrint('Error updating family member: $e');
      return false;
    }
  }

  /// Delete family member
  Future<bool> deleteFamilyMember(String id) async {
    try {
      await _repository.deleteFamilyMember(id);
      await fetchFamilyMembers(); // Refresh list
      return true;
    } catch (e) {
      debugPrint('Error deleting family member: $e');
      return false;
    }
  }
}

/// Family Member Provider
final familyMemberProvider = StateNotifierProvider<FamilyMemberNotifier, AsyncValue<List<FamilyMemberModel>>>(
  (ref) => FamilyMemberNotifier(FamilyMemberRepository()),
);
