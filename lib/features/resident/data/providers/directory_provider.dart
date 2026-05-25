import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../shared/models/paginated_state.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../models/directory_resident_model.dart';
import '../repositories/directory_repository.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DirectoryRepository(dioClient);
});

final directorySearchProvider = FutureProvider.autoDispose
    .family<List<DirectoryResident>, String>((ref, query) async {
  cacheFor(ref, const Duration(minutes: 10));
  final repo = ref.read(directoryRepositoryProvider);
  return repo.searchDirectory(query: query);
});

/// Paginated directory notifier — supports search + load-more.
class DirectoryListNotifier extends StateNotifier<PaginatedState<DirectoryResident>> {
  DirectoryListNotifier(this._repo) : super(const PaginatedState()) {
    loadInitial();
  }

  final DirectoryRepository _repo;
  static const _pageSize = 30;
  String _query = '';

  Future<void> loadInitial({String query = ''}) async {
    _query = query;
    state = const PaginatedState();
    try {
      final result = await _repo.searchDirectoryPaginated(
        query: _query.isEmpty ? null : _query,
        limit: _pageSize,
        offset: 0,
      );
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
      final result = await _repo.searchDirectoryPaginated(
        query: _query.isEmpty ? null : _query,
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

  Future<void> search(String query) async => loadInitial(query: query);
  Future<void> refresh() async => loadInitial(query: _query);
}

final paginatedDirectoryProvider = StateNotifierProvider.autoDispose<
    DirectoryListNotifier, PaginatedState<DirectoryResident>>(
  (ref) => DirectoryListNotifier(ref.watch(directoryRepositoryProvider)),
);
