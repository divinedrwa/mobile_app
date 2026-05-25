/// Pagination state shared across list screens.
///
/// Holds items, pagination metadata, and UI flags. Used by
/// [StateNotifier]-based providers that support load-more.
class PaginatedState<T> {
  const PaginatedState({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isInitialLoad = true,
    this.error,
  });

  final List<T> items;
  final int total;
  final int offset;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isInitialLoad;
  final String? error;

  PaginatedState<T> copyWith({
    List<T>? items,
    int? total,
    int? offset,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isInitialLoad,
    String? error,
    bool clearError = false,
  }) {
    return PaginatedState(
      items: items ?? this.items,
      total: total ?? this.total,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isInitialLoad: isInitialLoad ?? this.isInitialLoad,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
