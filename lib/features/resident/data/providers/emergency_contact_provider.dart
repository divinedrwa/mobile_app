import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/emergency_contact_model.dart';
import '../repositories/emergency_contact_repository.dart';

String _errorMessage(Object e) {
  if (e is AppException) return e.message;
  return 'Something went wrong. Please try again.';
}

class EmergencyContactNotifier
    extends StateNotifier<AsyncValue<List<EmergencyContactModel>>> {
  EmergencyContactNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    fetchContacts();
  }

  final EmergencyContactRepository _repository;

  Future<void> fetchContacts() async {
    state = const AsyncValue.loading();
    try {
      final contacts = await _repository.getContacts();
      state = AsyncValue.data(contacts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Add contact. Returns null on success, error message on failure.
  Future<String?> addContact({
    required String name,
    required String relationship,
    required String phone,
    String? address,
  }) async {
    try {
      await _repository.addContact(
        name: name,
        relationship: relationship,
        phone: phone,
        address: address,
      );
      await fetchContacts();
      return null;
    } catch (e) {
      debugPrint('Error adding emergency contact: $e');
      return _errorMessage(e);
    }
  }

  /// Delete contact. Returns null on success, error message on failure.
  Future<String?> deleteContact(String id) async {
    try {
      await _repository.deleteContact(id);
      await fetchContacts();
      return null;
    } catch (e) {
      debugPrint('Error deleting emergency contact: $e');
      return _errorMessage(e);
    }
  }
}

final emergencyContactProvider =
    StateNotifierProvider<
      EmergencyContactNotifier,
      AsyncValue<List<EmergencyContactModel>>
    >((ref) => EmergencyContactNotifier(EmergencyContactRepository()));
