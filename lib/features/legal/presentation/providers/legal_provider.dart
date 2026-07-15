import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/legal_repository.dart';

/// L2 — consent & terms versioning providers.
final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository();
});

/// Fetches the current legal versions + this user's acceptance state. Used by the
/// consent gate to display and submit the exact versions the server considers current.
final legalStatusProvider =
    FutureProvider.autoDispose<LegalConsentStatus>((ref) async {
  return ref.read(legalRepositoryProvider).getStatus();
});
