import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../resident/data/models/expense_category_model.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for recording and viewing society expenses.
///
/// Lists existing expenses with category filter chips,
/// a running total hero card, and a FAB to record new expenses
/// via a bottom sheet form.
class AdminExpensesScreen extends ConsumerStatefulWidget {
  const AdminExpensesScreen({super.key});

  @override
  ConsumerState<AdminExpensesScreen> createState() =>
      _AdminExpensesScreenState();
}

class _AdminExpensesScreenState extends ConsumerState<AdminExpensesScreen>
    with WidgetsBindingObserver {
  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );

  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(adminExpensesProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(adminExpensesProvider);
    ref.invalidate(adminExpenseCategoriesProvider);
    try {
      await ref.read(adminExpensesProvider.future);
    } catch (e) {
      debugPrint('AdminExpensesScreen._refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(adminExpensesProvider);
    final categoriesAsync = ref.watch(adminExpenseCategoriesProvider);
    final filter = ref.watch(adminExpenseFilterProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Society Expenses',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(categoriesAsync),
        backgroundColor: DesignColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Expense'),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80,
          ),
          children: [
            // ── Summary hero ──
            _buildSummaryHero(expensesAsync),
            const SizedBox(height: AppSpacing.lg),

            // ── Category filter chips ──
            _buildCategoryChips(categoriesAsync, filter.categoryId),
            const SizedBox(height: AppSpacing.sm),
            AdminSearchField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              hint: 'Search by title, paid to…',
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Expense list ──
            _buildExpenseList(expensesAsync),
          ],
        ),
      ),
    );
  }

  // ── Summary hero ────────────────────────────────────────────────────

  Widget _buildSummaryHero(AsyncValue async) {
    return async.when(
      loading: () => ShimmerWrap(
        child: ShimmerBox(height: 100, borderRadius: DesignRadius.xl),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final expenses = data as List;
        final total =
            expenses.fold<double>(0, (sum, e) => sum + (e.amount as double));
        final count = expenses.length;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: DesignColors.secondaryGradient,
            borderRadius: BorderRadius.circular(DesignRadius.xl),
            boxShadow: DesignElevation.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _inr.format(total),
                      style: DesignTypography.headingL.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count expense${count == 1 ? '' : 's'} recorded',
                      style: DesignTypography.caption
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Category filter chips ───────────────────────────────────────────

  Widget _buildCategoryChips(
      AsyncValue<List<ExpenseCategoryModel>> catAsync, String? activeCatId) {
    return catAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1, // +1 for "All"
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final cat = isAll ? null : categories[index - 1];
              final isSelected =
                  isAll ? activeCatId == null : activeCatId == cat!.id;

              return ChoiceChip(
                label: Text(isAll ? 'All' : cat!.name),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(adminExpenseFilterProvider.notifier).state =
                      ref.read(adminExpenseFilterProvider).copyWith(
                            categoryId: isAll ? null : cat!.id,
                            clearCategoryId: isAll,
                          );
                },
                selectedColor: DesignColors.primary,
                backgroundColor: DesignColors.surfaceSoft,
                labelStyle: DesignTypography.labelSmall.copyWith(
                  color:
                      isSelected ? Colors.white : DesignColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? DesignColors.primary
                      : DesignColors.borderLight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.full),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        );
      },
    );
  }

  // ── Expense list ────────────────────────────────────────────────────

  Widget _buildExpenseList(AsyncValue async) {
    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ShimmerWrap(
          child: Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShimmerBox(height: 56, borderRadius: DesignRadius.md),
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load expenses',
          subtitle: 'Pull down to refresh or try again.',
          iconColor: DesignColors.error,
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      ),
      data: (data) {
        var expenses = data as List;
        if (_searchQuery.isNotEmpty) {
          expenses = expenses.where((e) {
            final title = (e.title as String).toLowerCase();
            final paidTo = (e.paidTo as String).toLowerCase();
            final catName = (e.category?.name ?? '').toString().toLowerCase();
            return title.contains(_searchQuery) ||
                paidTo.contains(_searchQuery) ||
                catName.contains(_searchQuery);
          }).toList();
        }
        if (expenses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: 'No expenses recorded',
              subtitle: 'Tap "Record Expense" to add your first entry.',
              iconColor: DesignColors.primary,
            ),
          );
        }

        return Column(
          children: expenses.asMap().entries.map<Widget>((entry) {
            final idx = entry.key;
            final expense = entry.value;
            final title = expense.title as String;
            final amount = expense.amount as double;
            final paidTo = expense.paidTo as String;
            final paymentDate = expense.paymentDate as DateTime;
            final catName = expense.category?.name ?? '';
            final catColor = _parseCatColor(expense.category?.color);
            final mode = expense.paymentModeLabel as String;
            final id = expense.id as String;

            return Dismissible(
              key: ValueKey(id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: DesignColors.error,
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) => _confirmDelete(title),
              onDismissed: (_) => _deleteExpense(id),
              child: EnterprisePanel(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Category color dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: catColor ?? DesignColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: DesignTypography.label
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              paidTo,
                              DateFormat('dd MMM yy').format(paymentDate),
                              if (catName.isNotEmpty) catName,
                            ].join(' \u00b7 '),
                            style: DesignTypography.captionSmall
                                .copyWith(color: DesignColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _inr.format(amount),
                          style: DesignTypography.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DesignColors.textPrimary,
                          ),
                        ),
                        Text(
                          mode,
                          style: DesignTypography.captionSmall
                              .copyWith(color: DesignColors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate(delay: DesignAnimations.staggerFor(idx)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
          }).toList(),
        );
      },
    );
  }

  Future<bool> _confirmDelete(String title) async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => Container(
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
                  Container(width: 56, height: 56,
                      decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(Icons.delete_outline_rounded, color: DesignColors.error, size: 28)),
                  SizedBox(height: 16),
                  Text('Delete Expense?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Delete "$title"? This cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4)),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx, false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                      child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)))),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _deleteExpense(String id) async {
    try {
      await ref.read(adminExpenseRepositoryProvider).deleteExpense(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense deleted'),
          backgroundColor: DesignColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
      ref.invalidate(adminExpensesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e, 'Delete failed')),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
    }
  }

  void _showAddExpenseSheet(
      AsyncValue<List<ExpenseCategoryModel>> catAsync) {
    final categories = catAsync.valueOrNull ?? [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        categories: categories,
        onCreated: _refresh,
      ),
    );
  }

  static Color? _parseCatColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Add Expense Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({
    required this.categories,
    required this.onCreated,
  });

  final List<ExpenseCategoryModel> categories;
  final VoidCallback onCreated;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

const _paymentModes = <String, String>{
  'CASH': 'Cash',
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CHEQUE': 'Cheque',
  'ONLINE': 'Online',
};

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _paidToCtl = TextEditingController();
  final _descCtl = TextEditingController();

  String? _selectedCategoryId;
  String _selectedPaymentMode = 'CASH';
  DateTime _paymentDate = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _amountCtl.dispose();
    _paidToCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await ref.read(adminExpenseRepositoryProvider).createExpense(
            categoryId: _selectedCategoryId!,
            title: _titleCtl.text.trim(),
            amount: double.parse(_amountCtl.text.trim()),
            paymentDate: _paymentDate.toIso8601String(),
            paymentMode: _selectedPaymentMode,
            paidTo: _paidToCtl.text.trim(),
            description: _descCtl.text.trim().isEmpty
                ? null
                : _descCtl.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense recorded'),
          backgroundColor: DesignColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Record Expense', style: DesignTypography.headingM),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleCtl,
                decoration:
                    DesignComponents.inputDecoration(label: 'Title'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountCtl,
                decoration:
                    DesignComponents.inputDecoration(label: 'Amount (\u20b9)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Paid to
              TextFormField(
                controller: _paidToCtl,
                decoration:
                    DesignComponents.inputDecoration(label: 'Paid To'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Category dropdown
              Text('Category', style: DesignTypography.label),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration:
                    DesignComponents.inputDecoration(hint: 'Select category'),
                items: widget.categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child:
                              Text(c.name, style: DesignTypography.body),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedCategoryId = v),
                validator: (v) =>
                    v == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 12),

              // Payment mode
              Text('Payment Mode', style: DesignTypography.label),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMode,
                decoration: DesignComponents.inputDecoration(
                    hint: 'Select mode'),
                items: _paymentModes.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child:
                              Text(e.value, style: DesignTypography.body),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPaymentMode = v);
                },
              ),
              const SizedBox(height: 12),

              // Payment date
              Text('Payment Date', style: DesignTypography.label),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(DesignRadius.md),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: DesignColors.borderLight),
                    borderRadius:
                        BorderRadius.circular(DesignRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_paymentDate),
                          style: DesignTypography.body,
                        ),
                      ),
                      Icon(Icons.calendar_today,
                          size: 18, color: DesignColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description (optional)
              TextFormField(
                controller: _descCtl,
                decoration: DesignComponents.inputDecoration(
                    label: 'Description (optional)'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
