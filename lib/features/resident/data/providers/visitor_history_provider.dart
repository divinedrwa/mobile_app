import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/paginated_state.dart';
import '../../../../shared/utils/persistent_list_cache.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../models/visitor_model.dart';
import '../repositories/visitor_repository.dart';
import '../../presentation/providers/visitor_provider.dart';

typedef VisitorTodaySummary = ({
  int total,
  int checkedIn,
  int checkedOut,
});

const _visitorSummaryCacheName = 'visitor_today_summary';

VisitorTodaySummary? _readVisitorSummarySeed() {
  final key = PersistentListCache.scopedKey(_visitorSummaryCacheName);
  if (key == null) return null;
  return PersistentListCache.read<VisitorTodaySummary>(key, (json) {
    final m = Map<String, dynamic>.from(json as Map);
    return (
      total: (m['total'] as num?)?.toInt() ?? 0,
      checkedIn: (m['checkedIn'] as num?)?.toInt() ?? 0,
      checkedOut: (m['checkedOut'] as num?)?.toInt() ?? 0,
    );
  });
}

/// Synchronous cold-start seed for the visitor hub summary card so it paints
/// cached counts instead of a bare skeleton before the network fetch resolves.
final visitorTodaySummarySeedProvider = Provider<VisitorTodaySummary?>((ref) {
  return _readVisitorSummarySeed();
});

final visitorTodaySummaryProvider =
    FutureProvider.autoDispose<VisitorTodaySummary>((ref) async {
  cacheFor(ref, const Duration(minutes: 2));
  final summary =
      await ref.watch(visitorRepositoryProvider).getVisitorsTodaySummary();
  final key = PersistentListCache.scopedKey(_visitorSummaryCacheName);
  if (key != null) {
    await PersistentListCache.write(key, {
      'total': summary.total,
      'checkedIn': summary.checkedIn,
      'checkedOut': summary.checkedOut,
    });
  }
  return summary;
});

final visitorHistoryProvider = FutureProvider<List<VisitorModel>>((ref) async {
  return ref.watch(visitorRepositoryProvider).getVisitorHistory();
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
  (ref) => VisitorHistoryNotifier(ref.watch(visitorRepositoryProvider)),
);
