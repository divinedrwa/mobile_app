import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/models/paginated_state.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../repositories/complaint_repository.dart';
import '../models/complaint_list_item.dart';

class ComplaintSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  ComplaintSubmitNotifier(this._repository) : super(const AsyncValue.data(null));

  final ComplaintRepository _repository;

  Future<String?> submit({
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
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return e is AppException ? e.message : 'Something went wrong. Please try again.';
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
  cacheFor(ref, const Duration(minutes: 10));
  final repo = ref.watch(complaintRepositoryProvider);
  return repo.getMyComplaints();
});

/// Paginated complaint list notifier.
class ComplaintListNotifier extends StateNotifier<PaginatedState<ComplaintListItem>> {
  ComplaintListNotifier(this._repo) : super(const PaginatedState()) {
    loadInitial();
  }

  final ComplaintRepository _repo;
  static const _pageSize = 20;

  Future<void> loadInitial() async {
    state = const PaginatedState();
    try {
      final result = await _repo.getMyComplaintsPaginated(limit: _pageSize, offset: 0);
      state = PaginatedState(
        items: result.items,
        total: result.total,
        offset: result.items.length,
        hasMore: result.hasMore,
        isInitialLoad: false,
      );
    } catch (e) {
      state = PaginatedState(
        isInitialLoad: false,
        hasMore: false,
        error: e is AppException ? e.message : 'Failed to load complaints',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getMyComplaintsPaginated(
        limit: _pageSize,
        offset: state.offset,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        offset: state.offset + result.items.length,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e is AppException ? e.message : 'Failed to load more',
      );
    }
  }

  Future<void> refresh() async => loadInitial();
}

final paginatedComplaintsProvider = StateNotifierProvider.autoDispose<
    ComplaintListNotifier, PaginatedState<ComplaintListItem>>(
  (ref) => ComplaintListNotifier(ref.watch(complaintRepositoryProvider)),
);
