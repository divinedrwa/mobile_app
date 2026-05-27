import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../admin/data/providers/admin_providers.dart';
import '../../../data/providers/special_project_provider.dart';
import '../../../data/repositories/special_project_repository.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

enum _VillaMode { all, include, exclude }

class AdminCreateSpecialProjectScreen extends ConsumerStatefulWidget {
  const AdminCreateSpecialProjectScreen({super.key});

  @override
  ConsumerState<AdminCreateSpecialProjectScreen> createState() =>
      _AdminCreateSpecialProjectScreenState();
}

class _AdminCreateSpecialProjectScreenState
    extends ConsumerState<AdminCreateSpecialProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _villaSearchCtrl = TextEditingController();

  String _type = 'OTHER';
  DateTime? _dueDate;
  _VillaMode _villaMode = _VillaMode.all;
  final Set<String> _selectedVillaIds = {};
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _villaSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: DesignColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit(List<Map<String, dynamic>> allVillas) async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    // Determine which villas to include
    List<String> villaIds;
    switch (_villaMode) {
      case _VillaMode.all:
        villaIds = allVillas.map((v) => v['id'] as String).toList();
        break;
      case _VillaMode.include:
        villaIds = _selectedVillaIds.toList();
        break;
      case _VillaMode.exclude:
        villaIds = allVillas
            .where((v) => !_selectedVillaIds.contains(v['id']))
            .map((v) => v['id'] as String)
            .toList();
        break;
    }

    if (villaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one villa must be included')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final totalTarget = amount * villaIds.length;
      await SpecialProjectRepository().createProject({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'type': _type,
        'targetAmount': totalTarget,
        'contributions': villaIds
            .map((id) => {
                  'villaId': id,
                  'amount': amount,
                  if (_dueDate != null) 'dueDate': _dueDate!.toUtc().toIso8601String(),
                })
            .toList(),
      });

      if (!mounted) return;
      await ref.read(adminSpecialProjectsProvider.notifier).fetchProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project created successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final villasAsync = ref.watch(adminVillasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Project',
            style: DesignTypography.headingM
                .copyWith(color: DesignColors.textPrimary)),
      ),
      body: villasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load villas: $e')),
        data: (villas) => _buildForm(villas),
      ),
    );
  }

  Widget _buildForm(List<Map<String, dynamic>> allVillas) {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final villaCount = switch (_villaMode) {
      _VillaMode.all => allVillas.length,
      _VillaMode.include => _selectedVillaIds.length,
      _VillaMode.exclude =>
        allVillas.length - _selectedVillaIds.length,
    };
    final total = amount * villaCount;

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // ── Project Details ──
                Text('Project Details',
                    style: DesignTypography.headingM
                        .copyWith(color: DesignColors.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: DesignComponents.inputDecoration(
                      label: 'Title', hint: 'e.g. Swimming Pool Repair'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: DesignComponents.inputDecoration(label: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    DropdownMenuItem(value: 'REPAIR', child: Text('Repair')),
                    DropdownMenuItem(value: 'UPGRADE', child: Text('Upgrade')),
                    DropdownMenuItem(
                        value: 'PURCHASE', child: Text('Purchase')),
                    DropdownMenuItem(value: 'EVENT', child: Text('Event')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'OTHER'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descCtrl,
                  decoration: DesignComponents.inputDecoration(
                      label: 'Description', hint: 'Optional details'),
                  maxLines: 3,
                ),

                const SizedBox(height: AppSpacing.xl),
                // ── Contribution Setup ──
                Text('Contribution Setup',
                    style: DesignTypography.headingM
                        .copyWith(color: DesignColors.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: DesignComponents.inputDecoration(
                    label: 'Amount per Villa',
                    hint: 'e.g. 5000',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded,
                        size: 18, color: DesignColors.textTertiary),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                  child: InputDecorator(
                    decoration:
                        DesignComponents.inputDecoration(label: 'Due Date'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dueDate != null
                                ? DateFormat('dd MMM yyyy').format(_dueDate!)
                                : 'Optional',
                            style: DesignTypography.body.copyWith(
                              color: _dueDate != null
                                  ? DesignColors.textPrimary
                                  : DesignColors.textTertiary,
                            ),
                          ),
                        ),
                        if (_dueDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _dueDate = null),
                            child: const Icon(Icons.close, size: 18,
                                color: DesignColors.textTertiary),
                          )
                        else
                          const Icon(Icons.calendar_today_rounded, size: 18,
                              color: DesignColors.textTertiary),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                // ── Villa Selection Mode ──
                Text('Villa Selection',
                    style: DesignTypography.headingM
                        .copyWith(color: DesignColors.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<_VillaMode>(
                  segments: const [
                    ButtonSegment(
                        value: _VillaMode.all,
                        label: Text('All'),
                        icon: Icon(Icons.select_all_rounded, size: 18)),
                    ButtonSegment(
                        value: _VillaMode.include,
                        label: Text('Include'),
                        icon: Icon(Icons.add_circle_outline, size: 18)),
                    ButtonSegment(
                        value: _VillaMode.exclude,
                        label: Text('Exclude'),
                        icon: Icon(Icons.remove_circle_outline, size: 18)),
                  ],
                  selected: {_villaMode},
                  onSelectionChanged: (s) =>
                      setState(() {
                        _villaMode = s.first;
                        _selectedVillaIds.clear();
                      }),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected)
                            ? DesignColors.primary
                            : DesignColors.textSecondary),
                  ),
                ),

                if (_villaMode != _VillaMode.all) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildVillaSelector(allVillas),
                ],

                const SizedBox(height: AppSpacing.lg),
                // Summary
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: DesignColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(DesignRadius.md),
                    border: Border.all(
                        color: DesignColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: DesignColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '$villaCount villas selected — Total: ${_inr.format(total)}',
                          style: DesignTypography.label
                              .copyWith(color: DesignColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        // ── Sticky Bottom Button ──
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            border: Border(
                top: BorderSide(color: DesignColors.borderLight)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submitting ? null : () => _submit(allVillas),
              style: DesignComponents.primaryButtonStyle,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Create Project',
                      style: DesignTypography.button
                          .copyWith(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVillaSelector(List<Map<String, dynamic>> allVillas) {
    final query = _villaSearchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? allVillas
        : allVillas.where((v) {
            final num = (v['villaNumber'] as String? ?? '').toLowerCase();
            final owner = (v['ownerName'] as String? ?? '').toLowerCase();
            return num.contains(query) || owner.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _villaSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: DesignComponents.inputDecoration(
            hint: 'Search villas…',
            prefixIcon: const Icon(Icons.search, size: 18,
                color: DesignColors.textTertiary),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() =>
                  _selectedVillaIds.addAll(
                      filtered.map((v) => v['id'] as String))),
              child: Text('Select All',
                  style: DesignTypography.labelSmall
                      .copyWith(color: DesignColors.primary)),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => setState(() => _selectedVillaIds.clear()),
              child: Text('Clear',
                  style: DesignTypography.labelSmall
                      .copyWith(color: DesignColors.textTertiary)),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final villa = filtered[i];
              final id = villa['id'] as String;
              final isSelected = _selectedVillaIds.contains(id);
              final villaNum = villa['villaNumber'] as String? ?? '—';
              final owner = villa['ownerName'] as String? ?? '';

              return CheckboxListTile(
                value: isSelected,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: DesignColors.primary,
                title: Text('Villa $villaNum',
                    style: DesignTypography.label
                        .copyWith(color: DesignColors.textPrimary)),
                subtitle: owner.isNotEmpty
                    ? Text(owner,
                        style: DesignTypography.captionSmall
                            .copyWith(color: DesignColors.textTertiary))
                    : null,
                onChanged: (_) => setState(() {
                  if (isSelected) {
                    _selectedVillaIds.remove(id);
                  } else {
                    _selectedVillaIds.add(id);
                  }
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
