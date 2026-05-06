import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/security_contact_model.dart';
import '../repositories/security_contact_repository.dart';

final securityContactRepositoryProvider = Provider<SecurityContactRepository>(
  (ref) => SecurityContactRepository(),
);

final securityContactsProvider = FutureProvider<List<SecurityContactModel>>((ref) async {
  return ref.watch(securityContactRepositoryProvider).getSecurityContacts();
});
