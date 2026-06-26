import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../theme/context_extensions.dart';
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
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        leading: _showSearch
            ? IconButton(
                tooltip: 'Close search',
                onPressed: _toggleSearch,
                icon: Icon(Icons.close_rounded, size: 20, color: context.text.primary),
              )
            : IconButton(
                tooltip: 'Go back',
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
              ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontSize: 16,
                  color: context.text.primary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: TextStyle(
                    color: context.text.tertiary,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: context.text.primary,
                    ),
                  ),
                  Text(
                    'Approved society expenditures',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.text.secondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: _showSearch ? 'Close' : 'Search',
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: context.text.secondary,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.spacing.s16,
            context.spacing.s4,
            context.spacing.s16,
            context.spacing.s32,
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
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
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
            const SizedBox(height: 12),

            // Expenses list
            expensesAsync.when(
              loading: () => const ListSkeleton(itemHeight: 96),
              error: (e, _) => EnterpriseInfoBanner(
                icon: Icons.receipt_long_outlined,
                title: 'Could not load expenses',
                message: 'Check your connection and pull down to retry.',
                tone: EnterpriseTone.danger,
                actionLabel: 'Retry',
                onAction: _refresh,
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
                      const SizedBox(height: 8),
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
      color: context.surface.defaultSurface,
      borderRadius: DesignRadius.borderLG,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignRadius.borderLG,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: context.surface.border),
            borderRadius: DesignRadius.borderLG,
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
              const SizedBox(width: 10),
              // Title + paid-to + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.text.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expense.paidTo}  •  ${dateFmt.format(expense.paymentDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.text.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount + attachment badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inr.format(expense.amount),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.text.primary,
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
                          color: context.text.tertiary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${expense.attachmentCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.text.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: context.text.tertiary,
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
