import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emergency_contact_model.dart';
import '../repositories/emergency_contact_repository.dart';

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

  Future<bool> addContact({
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
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      await _repository.deleteContact(id);
      await fetchContacts();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final emergencyContactProvider =
    StateNotifierProvider<
      EmergencyContactNotifier,
      AsyncValue<List<EmergencyContactModel>>
    >((ref) => EmergencyContactNotifier(EmergencyContactRepository()));
