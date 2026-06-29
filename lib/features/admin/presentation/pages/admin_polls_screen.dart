import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing polls.
class AdminPollsScreen extends ConsumerStatefulWidget {
  const AdminPollsScreen({super.key});

  @override
  ConsumerState<AdminPollsScreen> createState() => _AdminPollsScreenState();
}

class _AdminPollsScreenState extends ConsumerState<AdminPollsScreen> {
  String? _statusFilter; // null = All, 'ACTIVE', 'CLOSED'

  Future<void> _refresh() async {
    ref.invalidate(adminPollsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pollsAsync = ref.watch(adminPollsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Polls',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon:
                Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DesignColors.primary,
        onPressed: () => _showCreateSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: pollsAsync.when(
          loading: () => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ShimmerWrap(
                child: Column(
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShimmerBox(height: 140, borderRadius: DesignRadius.lg),
                    ),
                  ),
                ),
              ),
            ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load polls',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (polls) => _buildBody(polls),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> polls) {
    // Determine status per poll
    final now = DateTime.now();
    final enriched = polls.map((p) {
      final endDate = DateTime.tryParse(p['endDate']?.toString() ?? '');
      final isClosed = p['isClosed'] == true ||
          (endDate != null && endDate.isBefore(now));
      return {...p, '_isActive': !isClosed};
    }).toList();

    final filtered = _statusFilter == null
        ? enriched
        : _statusFilter == 'ACTIVE'
            ? enriched.where((p) => p['_isActive'] == true).toList()
            : enriched.where((p) => p['_isActive'] != true).toList();

    final activeCount = enriched.where((p) => p['_isActive'] == true).length;
    final closedCount = enriched.length - activeCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Filter chips
        _buildFilterChips(enriched.length, activeCount, closedCount),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.how_to_vote_outlined,
              title: 'No polls found',
              subtitle: _statusFilter != null
                  ? 'No polls match the selected filter.'
                  : 'Create a poll to gather opinions from residents.',
              iconColor: DesignColors.primary,
            ),
          )
        else
          ...filtered.asMap().entries.map((e) => _pollCard(e.value, e.key)),
      ],
    );
  }

  Widget _buildFilterChips(int total, int active, int closed) {
    final labels = <String?, String>{
      null: 'All ($total)',
      'ACTIVE': 'Active ($active)',
      'CLOSED': 'Closed ($closed)',
    };

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = labels.entries.elementAt(index);
          final isSelected = _statusFilter == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: isSelected,
            onSelected: (_) => setState(() => _statusFilter = entry.key),
            selectedColor: DesignColors.primary,
            backgroundColor: DesignColors.surfaceSoft,
            labelStyle: DesignTypography.labelSmall.copyWith(
              color: isSelected ? Colors.white : DesignColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected
                  ? DesignColors.primary
                  : DesignColors.borderLight,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignRadius.full)),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _pollCard(Map<String, dynamic> poll, [int index = 0]) {
    final id = poll['id']?.toString() ?? '';
    final title = poll['title']?.toString() ?? '';
    final description = poll['description']?.toString();
    final isActive = poll['_isActive'] == true;
    final options =
        (poll['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Compute total votes
    int totalVotes = 0;
    for (final o in options) {
      totalVotes += ((o['_count'] as Map?)?['votes'] as num?)?.toInt() ??
          (o['voteCount'] as num?)?.toInt() ??
          0;
    }

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: DesignTypography.label
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isActive
                          ? DesignColors.primary
                          : DesignColors.textTertiary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isActive ? 'Active' : 'Closed',
                  style: DesignTypography.captionSmall.copyWith(
                    color: isActive
                        ? DesignColors.primary
                        : DesignColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description,
                style: DesignTypography.captionSmall
                    .copyWith(color: DesignColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text('$totalVotes votes',
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textTertiary)),
          const SizedBox(height: 10),

          // Option bars
          ...options.map((o) {
            final optionText = o['text']?.toString() ?? '';
            final voteCount =
                ((o['_count'] as Map?)?['votes'] as num?)?.toInt() ??
                    (o['voteCount'] as num?)?.toInt() ??
                    0;
            final pct = totalVotes > 0 ? voteCount / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(optionText,
                            style: DesignTypography.captionSmall.copyWith(
                                fontWeight: FontWeight.w500,
                                color: DesignColors.textPrimary)),
                      ),
                      Text('${(pct * 100).round()}%',
                          style: DesignTypography.captionSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: DesignColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: DesignColors.surfaceSoft,
                      valueColor: AlwaysStoppedAnimation(
                          DesignColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Close action for active polls
          if (isActive) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _confirmClose(id, title),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: DesignColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignRadius.full),
                  ),
                  child: Text('Close Poll',
                      style: DesignTypography.labelSmall.copyWith(
                          color: DesignColors.error,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  void _confirmClose(String id, String title) {
    showModalBottomSheet<void>(
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
                  child: Icon(Icons.lock_outline_rounded, color: DesignColors.error, size: 28)),
              SizedBox(height: 16),
              Text('Close Poll?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Close "$title"? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      await ref.read(adminPollRepositoryProvider).closePoll(id);
                      ref.invalidate(adminPollsProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Poll closed'),
                          backgroundColor: DesignColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(userFacingMessage(e)),
                          backgroundColor: DesignColors.error,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Close Poll', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePollSheet(onCreated: _refresh),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Create Poll Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _CreatePollSheet extends ConsumerStatefulWidget {
  const _CreatePollSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<_CreatePollSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('At least 2 options required'),
        backgroundColor: DesignColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);

    try {
      await ref.read(adminPollRepositoryProvider).createPoll(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            // Backend requires an ISO-8601 UTC datetime (with `Z`); a local
            // `toIso8601String()` has no offset and is rejected (400).
            startDate: _startDate.toUtc().toIso8601String(),
            endDate: _endDate.toUtc().toIso8601String(),
            options: options,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Poll created'),
        backgroundColor: DesignColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFacingMessage(e)),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text('Create Poll', style: DesignTypography.headingM),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _titleCtrl,
                  decoration:
                      DesignComponents.inputDecoration(label: 'Title'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descCtrl,
                  decoration: DesignComponents.inputDecoration(
                      label: 'Description (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Date pickers
                Row(
                  children: [
                    Expanded(
                      child: _datePicker(
                          'Start', _startDate, () => _pickDate(true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          _datePicker('End', _endDate, () => _pickDate(false)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Options
                Text('Options', style: DesignTypography.labelSmall),
                const SizedBox(height: 8),
                ..._optionCtrls.asMap().entries.map((entry) {
                  final i = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ctrl,
                            decoration: DesignComponents.inputDecoration(
                                hint: 'Option ${i + 1}'),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        if (_optionCtrls.length > 2)
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                color: DesignColors.error, size: 20),
                            onPressed: () => _removeOption(i),
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Option'),
                ),
                const SizedBox(height: 16),

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
                        : const Text('Create Poll', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: DesignColors.borderLight),
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 16, color: DesignColors.textTertiary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textTertiary)),
                Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: DesignTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
