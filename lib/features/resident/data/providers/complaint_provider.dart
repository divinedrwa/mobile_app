import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/complaint_repository.dart';
import '../models/complaint_list_item.dart';

class ComplaintSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  ComplaintSubmitNotifier(this._repository) : super(const AsyncValue.data(null));

  final ComplaintRepository _repository;

  Future<bool> submit({
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.submitComplaint(
        title: title,
        description: description,
        category: category,
        priority: priority,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => ComplaintRepository(),
);

final complaintSubmitProvider =
    StateNotifierProvider<ComplaintSubmitNotifier, AsyncValue<void>>(
  (ref) => ComplaintSubmitNotifier(ref.watch(complaintRepositoryProvider)),
);

final myComplaintsProvider =
    FutureProvider.autoDispose<List<ComplaintListItem>>((ref) async {
  final repo = ref.watch(complaintRepositoryProvider);
  return repo.getMyComplaints();
});
