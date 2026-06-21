import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../widgets/list_skeleton.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../data/models/expense_model.dart';
import '../../data/providers/expense_provider.dart';

class SocietyExpensesScreen extends ConsumerStatefulWidget {
  const SocietyExpensesScreen({super.key, this.initialMonth, this.initialYear});

  final int? initialMonth;
  final int? initialYear;

  @override
  ConsumerState<SocietyExpensesScreen> createState() =>
      _SocietyExpensesScreenState();
}

class _SocietyExpensesScreenState
    extends ConsumerState<SocietyExpensesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _showSearch = false;
  bool _didInit = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final current = ref.read(expenseFilterProvider);
      ref.read(expenseFilterProvider.notifier).state = current.copyWith(
        search: value.trim().isEmpty ? null : value.trim(),
        clearSearch: value.trim().isEmpty,
      );
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        final current = ref.read(expenseFilterProvider);
        ref.read(expenseFilterProvider.notifier).state =
            current.copyWith(clearSearch: true);
      }
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(expensesProvider);
    await ref.read(expensesProvider.future).catchError((_) => <ExpenseModel>[]);
  }

  @override
  Widget build(BuildContext context) {
    // Seed the filter with initial month/year on first build.
    if (!_didInit) {
      _didInit = true;
      if (widget.initialMonth != null || widget.initialYear != null) {
        Future.microtask(() {
          ref.read(expenseFilterProvider.notifier).state = ExpenseFilter(
            month: widget.initialMonth,
            year: widget.initialYear,
          );
        });
      }
    }

    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final filter = ref.watch(expenseFilterProvider);
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM yyyy');

    final hasMonthFilter = filter.month != null && filter.year != null;
    final titleText = hasMonthFilter
        ? 'Expenses \u2022 ${DateFormat('MMM yyyy').format(DateTime(filter.year!, filter.month!))}'
        : 'Society Expenses';

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                titleText,
                style: DesignTypography.headingM.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close : Icons.search,
              color: DesignColors.textSecondary,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            // Category filter chips
            categoriesAsync.when(
              loading: () => const ChipRowSkeleton(height: 40),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) {
                if (categories.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = filter.categoryId == null;
                        return FilterChip(
                          selected: isSelected,
                          label: const Text('All'),
                          labelStyle: DesignTypography.caption.copyWith(
                            color: isSelected
                                ? Colors.white
                                : DesignColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: DesignColors.primary,
                          backgroundColor: DesignColors.surface,
                          side: BorderSide(
                            color: isSelected
                                ? DesignColors.primary
                                : DesignColors.borderLight,
                          ),
                          showCheckmark: false,
                          onSelected: (_) {
                            ref
                                .read(expenseFilterProvider.notifier)
                                .state = filter.copyWith(
                              clearCategoryId: true,
                            );
                          },
                        );
                      }
                      final cat = categories[index - 1];
                      final isSelected = filter.categoryId == cat.id;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(cat.name),
                        labelStyle: DesignTypography.caption.copyWith(
                          color: isSelected
                              ? Colors.white
                              : DesignColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: DesignColors.primary,
                        backgroundColor: DesignColors.surface,
                        side: BorderSide(
                          color: isSelected
                              ? DesignColors.primary
                              : DesignColors.borderLight,
                        ),
                        showCheckmark: false,
                        onSelected: (_) {
                          ref.read(expenseFilterProvider.notifier).state =
                              isSelected
                                  ? filter.copyWith(clearCategoryId: true)
                                  : filter.copyWith(categoryId: cat.id);
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Expenses list
            expensesAsync.when(
              loading: () => const ListSkeleton(itemHeight: 96),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    'Failed to load expenses.\nPull down to retry.',
                    textAlign: TextAlign.center,
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.error,
                    ),
                  ),
                ),
              ),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses found',
                      subtitle:
                          'There are no approved expenses matching your filters.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final expense in expenses) ...[
                      _ExpenseCard(
                        expense: expense,
                        inr: inr,
                        dateFmt: dateFmt,
                        onTap: () => context.push(
                          '/resident/expenses/${expense.id}',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.inr,
    required this.dateFmt,
    required this.onTap,
  });

  final ExpenseModel expense;
  final NumberFormat inr;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = _parseColor(expense.category?.color) ??
        DesignColors.primary;
    final hasAttachments = expense.attachmentCount > 0;

    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: Row(
            children: [
              // Category color dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: catColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              // Title + paid-to + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTypography.bodyMedium.copyWith(
                        color: DesignColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expense.paidTo}  •  ${dateFmt.format(expense.paymentDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTypography.caption.copyWith(
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Amount + attachment badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inr.format(expense.amount),
                    style: DesignTypography.bodyMedium.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasAttachments) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 12,
                          color: DesignColors.textTertiary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${expense.attachmentCount}',
                          style: DesignTypography.caption.copyWith(
                            color: DesignColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: DesignColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}
