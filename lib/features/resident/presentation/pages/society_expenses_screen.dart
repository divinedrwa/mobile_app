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
import '../../data/models/expense_billing_cycle_group.dart';
import '../../data/models/expense_model.dart';
import '../../data/providers/expense_provider.dart';
import '../../data/providers/dashboard_provider.dart';

class SocietyExpensesScreen extends ConsumerStatefulWidget {
  const SocietyExpensesScreen({
    super.key,
    this.initialMonth,
    this.initialYear,
    this.highlightInitialCycle = false,
  });

  final int? initialMonth;
  final int? initialYear;
  final bool highlightInitialCycle;

  @override
  ConsumerState<SocietyExpensesScreen> createState() =>
      _SocietyExpensesScreenState();
}

class _SocietyExpensesScreenState
    extends ConsumerState<SocietyExpensesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _highlightSectionKey = GlobalKey();
  Timer? _debounce;
  bool _showSearch = false;
  bool _didScrollToHighlight = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool _groupMatchesHighlight(ExpenseBillingCycleGroup group) {
    if (widget.initialMonth == null || widget.initialYear == null) return false;
    return group.month == widget.initialMonth && group.year == widget.initialYear;
  }

  void _maybeScrollToHighlightedGroup(List<ExpenseBillingCycleGroup> groups) {
    if (!widget.highlightInitialCycle || _didScrollToHighlight) return;
    if (widget.initialMonth == null || widget.initialYear == null) return;
    if (!groups.any(_groupMatchesHighlight)) return;

    _didScrollToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
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
    ref.invalidate(
      societyExpensesGroupedProvider((widget.initialMonth, widget.initialYear)),
    );
    ref.invalidate(residentDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final routeKey = (widget.initialMonth, widget.initialYear);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final groupsAsync = ref.watch(societyExpensesGroupedProvider(routeKey));
    final filter = ref.watch(expenseFilterProvider);
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM yyyy');

    final displayMonth = widget.initialMonth ?? filter.month;
    final displayYear = widget.initialYear ?? filter.year;
    final hasMonthFilter = displayMonth != null && displayYear != null;
    final titleText = hasMonthFilter
        ? 'Expenses \u2022 ${DateFormat('MMM yyyy').format(DateTime(displayYear, displayMonth))}'
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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
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

            // Expenses grouped by billing cycle
            groupsAsync.when(
              // ListSkeleton builds its own (non-scrolling) ListView. Nested
              // directly inside this outer ListView it gets an unbounded height
              // constraint and throws a layout error — the screen renders black
              // for the whole fetch (only visible when the data isn't cached,
              // e.g. after switching to a different billing cycle). A bounded
              // SizedBox gives the skeleton a finite height and avoids the crash.
              loading: () => const SizedBox(
                height: 520,
                child: ListSkeleton(itemHeight: 96),
              ),
              error: (e, _) => EnterpriseInfoBanner(
                icon: Icons.receipt_long_outlined,
                title: 'Could not load expenses',
                message: 'Check your connection and pull down to retry.',
                tone: EnterpriseTone.danger,
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: hasMonthFilter
                          ? 'No expenses for ${DateFormat('MMM yyyy').format(DateTime(displayYear, displayMonth))}'
                          : 'No expenses found',
                      subtitle: hasMonthFilter
                          ? 'There are no approved expenses recorded for this billing cycle.'
                          : 'There are no approved expenses matching your filters.',
                    ),
                  );
                }
                _maybeScrollToHighlightedGroup(groups);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in groups) ...[
                      _BillingCycleGroupSection(
                        key: widget.highlightInitialCycle &&
                                _groupMatchesHighlight(group)
                            ? _highlightSectionKey
                            : null,
                        group: group,
                        inr: inr,
                        dateFmt: dateFmt,
                        highlighted: widget.highlightInitialCycle &&
                            _groupMatchesHighlight(group),
                        onExpenseTap: (id) =>
                            context.push('/resident/expenses/$id'),
                      ),
                      const SizedBox(height: 16),
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

class _BillingCycleGroupSection extends StatelessWidget {
  const _BillingCycleGroupSection({
    super.key,
    required this.group,
    required this.inr,
    required this.dateFmt,
    required this.highlighted,
    required this.onExpenseTap,
  });

  final ExpenseBillingCycleGroup group;
  final NumberFormat inr;
  final DateFormat dateFmt;
  final bool highlighted;
  final void Function(String id) onExpenseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BillingCycleGroupHeader(
          group: group,
          inr: inr,
          highlighted: highlighted,
        ),
        const SizedBox(height: 8),
        for (final expense in group.expenses) ...[
          _ExpenseCard(
            expense: expense,
            inr: inr,
            dateFmt: dateFmt,
            onTap: () => onExpenseTap(expense.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BillingCycleGroupHeader extends StatelessWidget {
  const _BillingCycleGroupHeader({
    required this.group,
    required this.inr,
    this.highlighted = false,
  });

  final ExpenseBillingCycleGroup group;
  final NumberFormat inr;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final badge = _phaseBadge(context, group.phase);
    final subtitleParts = <String>[
      inr.format(group.totalAmount),
      '${group.expenseCount} ${group.expenseCount == 1 ? 'item' : 'items'}',
    ];
    final accent = switch (group.phase) {
      ExpenseCyclePhase.draft || ExpenseCyclePhase.upcoming => DesignColors.info,
      ExpenseCyclePhase.open => DesignColors.success,
      _ => DesignColors.primary,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: 0.06)
            : context.surface.defaultSurface,
        borderRadius: DesignRadius.borderLG,
        border: Border.all(
          color: highlighted ? accent.withValues(alpha: 0.45) : context.surface.border,
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.text.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join('  •  '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.text.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _phaseBadge(BuildContext context, ExpenseCyclePhase phase) {
    if (phase == ExpenseCyclePhase.closed ||
        phase == ExpenseCyclePhase.noCycle) {
      return null;
    }

    final (bg, fg) = switch (phase) {
      ExpenseCyclePhase.draft || ExpenseCyclePhase.upcoming => (
          DesignColors.info.withValues(alpha: 0.14),
          DesignColors.info,
        ),
      ExpenseCyclePhase.open => (
          DesignColors.success.withValues(alpha: 0.14),
          DesignColors.success,
        ),
      _ => (Colors.transparent, context.text.secondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        phase.residentLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
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
