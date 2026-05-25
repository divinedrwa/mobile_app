import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/models/paginated_state.dart';
import '../models/visitor_model.dart';
import '../repositories/visitor_repository.dart';

final visitorHistoryRepositoryProvider = Provider<VisitorRepository>(
  (ref) => VisitorRepository(DioClient()),
);

final visitorHistoryProvider = FutureProvider<List<VisitorModel>>((ref) async {
  return ref.watch(visitorHistoryRepositoryProvider).getVisitorHistory();
});

/// Paginated visitor history notifier.
class VisitorHistoryNotifier extends StateNotifier<PaginatedState<VisitorModel>> {
  VisitorHistoryNotifier(this._repo) : super(const PaginatedState()) {
    loadInitial();
  }

  final VisitorRepository _repo;
  static const _pageSize = 20;

  Future<void> loadInitial() async {
    state = const PaginatedState();
    try {
      final result = await _repo.getVisitorHistoryPaginated(limit: _pageSize, offset: 0);
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
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getVisitorHistoryPaginated(
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
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async => loadInitial();
}

final paginatedVisitorHistoryProvider = StateNotifierProvider.autoDispose<
    VisitorHistoryNotifier, PaginatedState<VisitorModel>>(
  (ref) => VisitorHistoryNotifier(ref.watch(visitorHistoryRepositoryProvider)),
);
