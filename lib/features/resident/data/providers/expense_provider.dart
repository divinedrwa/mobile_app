import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(),
);

final expenseCategoriesProvider =
    FutureProvider.autoDispose<List<ExpenseCategoryModel>>((ref) async {
  // Categories are config-like — cache to avoid re-downloading on every visit.
  cacheFor(ref, const Duration(minutes: 10));
  return ref.watch(expenseRepositoryProvider).getCategories();
});

class ExpenseFilter {
  final String? categoryId;
  final int? month;
  final int? year;
  final String? search;

  const ExpenseFilter({this.categoryId, this.month, this.year, this.search});

  ExpenseFilter copyWith({
    String? categoryId,
    int? month,
    int? year,
    String? search,
    bool clearCategoryId = false,
    bool clearMonth = false,
    bool clearYear = false,
    bool clearSearch = false,
  }) {
    return ExpenseFilter(
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      month: clearMonth ? null : (month ?? this.month),
      year: clearYear ? null : (year ?? this.year),
      search: clearSearch ? null : (search ?? this.search),
    );
  }
}

final expenseFilterProvider = StateProvider<ExpenseFilter>(
  (ref) => const ExpenseFilter(),
);

/// Fetches expenses for a route period (`?month=&year=`). Route params take
/// precedence over [expenseFilterProvider] month/year so billing-cycle changes
/// always match the list on screen.
final societyExpensesListProvider = FutureProvider.autoDispose
    .family<List<ExpenseModel>, (int?, int?)>((ref, routeKey) async {
  // Cache per (month, year) so re-opening a cycle's expenses is instant and
  // switching back and forth between months doesn't re-hit the network.
  cacheFor(ref, const Duration(minutes: 2));
  final (routeMonth, routeYear) = routeKey;
  final filter = ref.watch(expenseFilterProvider);
  final month = routeMonth ?? filter.month;
  final year = routeYear ?? filter.year;
  final result = await ref.watch(expenseRepositoryProvider).getExpenses(
        categoryId: filter.categoryId,
        month: month,
        year: year,
        search: filter.search,
        limit: 50,
      );
  return result.expenses;
});

final expensesProvider =
    FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final filter = ref.watch(expenseFilterProvider);
  final result = await ref.watch(expenseRepositoryProvider).getExpenses(
        categoryId: filter.categoryId,
        month: filter.month,
        year: filter.year,
        search: filter.search,
        limit: 50,
      );
  return result.expenses;
});

final expenseDetailProvider =
    FutureProvider.autoDispose.family<ExpenseModel, String>(
  (ref, id) => ref.watch(expenseRepositoryProvider).getExpenseById(id),
);
