import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../resident/data/models/notice_model.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for creating and viewing society notices.
///
/// Shows existing notices in reverse-chronological order with
/// category/priority badges and a FAB to broadcast a new notice.
class AdminNoticesScreen extends ConsumerStatefulWidget {
  const AdminNoticesScreen({super.key});

  @override
  ConsumerState<AdminNoticesScreen> createState() =>
      _AdminNoticesScreenState();
}

class _AdminNoticesScreenState extends ConsumerState<AdminNoticesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(adminNoticesProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(adminNoticesProvider);
    try {
      await ref.read(adminNoticesProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(adminNoticesProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Notices',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: DesignColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign),
        label: const Text('New Notice'),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: noticesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerBox(height: 90, borderRadius: DesignRadius.lg),
                )),
              ),
            ),
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load notices',
                  subtitle: 'Pull down to refresh or try again',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (notices) {
            if (notices.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.campaign_outlined,
                      title: 'No notices yet',
                      subtitle: 'Tap + to broadcast a notice',
                      iconColor: DesignColors.primary,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _noticeCard(notices[index]),
            );
          },
        ),
      ),
    );
  }

  // ── Notice card ─────────────────────────────────────────────────────

  Widget _noticeCard(NoticeModel notice) {
    final dateStr = _formatDate(notice.publishedAt);

    return Dismissible(
      key: ValueKey(notice.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: DesignColors.error,
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(notice.title),
      onDismissed: (_) => _deleteNotice(notice.id),
      child: EnterprisePanel(
        padding: const EdgeInsets.all(14),
        tone: notice.isUrgent ? EnterpriseTone.danger : EnterpriseTone.neutral,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (notice.isUrgent) _badge('URGENT', DesignColors.error),
                _badge(
                  _categoryLabel(notice.category),
                  _categoryColor(notice.category),
                ),
                if (notice.priority != NoticePriority.normal)
                  _badge(
                    notice.priority.value,
                    _priorityColor(notice.priority),
                  ),
                if (notice.isNew) _badge('NEW', DesignColors.accent),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              notice.title,
              style: DesignTypography.label
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Content preview
            Text(
              notice.content,
              style: DesignTypography.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Footer
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 13, color: DesignColors.textTertiary),
                const SizedBox(width: 4),
                Text(dateStr, style: DesignTypography.captionSmall),
                if (notice.attachmentUrl != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.attach_file,
                      size: 13, color: DesignColors.textTertiary),
                  const SizedBox(width: 2),
                  Text('Attachment', style: DesignTypography.captionSmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: DesignTypography.captionSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateNoticeSheet(onCreated: _refresh),
    );
  }

  Future<bool> _confirmDelete(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Notice'),
            content: Text('Delete "$title"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    TextButton.styleFrom(foregroundColor: DesignColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _deleteNotice(String id) async {
    try {
      await ref.read(adminNoticeRepositoryProvider).deleteNotice(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notice deleted'),
          backgroundColor: DesignColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
      ref.invalidate(adminNoticesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today ${DateFormat.jm().format(dt)}';
    if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat.jm().format(dt)}';
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String _categoryLabel(NoticeCategory cat) {
    switch (cat) {
      case NoticeCategory.general:
        return 'GENERAL';
      case NoticeCategory.maintenance:
        return 'MAINTENANCE';
      case NoticeCategory.event:
        return 'EVENT';
      case NoticeCategory.emergency:
        return 'EMERGENCY';
      case NoticeCategory.announcement:
        return 'ANNOUNCEMENT';
      case NoticeCategory.meeting:
        return 'MEETING';
    }
  }

  static Color _categoryColor(NoticeCategory cat) {
    switch (cat) {
      case NoticeCategory.emergency:
        return DesignColors.error;
      case NoticeCategory.maintenance:
        return DesignColors.warning;
      case NoticeCategory.event:
        return DesignColors.accent;
      case NoticeCategory.meeting:
        return DesignColors.info;
      case NoticeCategory.announcement:
        return DesignColors.primary;
      case NoticeCategory.general:
        return DesignColors.textSecondary;
    }
  }

  static Color _priorityColor(NoticePriority p) {
    switch (p) {
      case NoticePriority.urgent:
        return DesignColors.error;
      case NoticePriority.high:
        return DesignColors.warning;
      case NoticePriority.normal:
        return DesignColors.textSecondary;
      case NoticePriority.low:
        return DesignColors.textTertiary;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Create Notice Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _CreateNoticeSheet extends ConsumerStatefulWidget {
  const _CreateNoticeSheet({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateNoticeSheet> createState() =>
      _CreateNoticeSheetState();
}

class _CreateNoticeSheetState extends ConsumerState<_CreateNoticeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _contentCtl = TextEditingController();

  String _selectedCategory = 'GENERAL';
  String _selectedPriority = 'NORMAL';
  bool _isUrgent = false;
  bool _notifyResidents = true;
  bool _submitting = false;

  static const _categories = <String, String>{
    'GENERAL': 'General',
    'MAINTENANCE': 'Maintenance',
    'EVENT': 'Event',
    'EMERGENCY': 'Emergency',
    'ANNOUNCEMENT': 'Announcement',
    'MEETING': 'Meeting',
  };

  static const _priorities = <String, String>{
    'LOW': 'Low',
    'NORMAL': 'Normal',
    'HIGH': 'High',
    'URGENT': 'Urgent',
  };

  @override
  void dispose() {
    _titleCtl.dispose();
    _contentCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await ref.read(adminNoticeRepositoryProvider).createNotice(
            title: _titleCtl.text.trim(),
            content: _contentCtl.text.trim(),
            category: _selectedCategory,
            priority: _selectedPriority,
            isUrgent: _isUrgent,
            notifyResidents: _notifyResidents,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_notifyResidents
              ? 'Notice sent to all residents'
              : 'Notice created'),
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
          content: Text('Failed: $e'),
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

              Text('Broadcast Notice', style: DesignTypography.headingM),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleCtl,
                decoration:
                    DesignComponents.inputDecoration(label: 'Title'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().length < 3) {
                    return 'At least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Content
              TextFormField(
                controller: _contentCtl,
                decoration:
                    DesignComponents.inputDecoration(label: 'Content'),
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'At least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Category + Priority row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category', style: DesignTypography.label),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: DesignComponents.inputDecoration(
                              hint: 'Category'),
                          isExpanded: true,
                          items: _categories.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value,
                                        style: DesignTypography.bodySmall),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedCategory = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Priority', style: DesignTypography.label),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPriority,
                          decoration: DesignComponents.inputDecoration(
                              hint: 'Priority'),
                          isExpanded: true,
                          items: _priorities.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value,
                                        style: DesignTypography.bodySmall),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedPriority = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Toggles
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      title: Text('Mark Urgent',
                          style: DesignTypography.labelSmall),
                      value: _isUrgent,
                      onChanged: (v) => setState(() => _isUrgent = v),
                      activeTrackColor: DesignColors.error,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      title: Text('Push Notify',
                          style: DesignTypography.labelSmall),
                      value: _notifyResidents,
                      onChanged: (v) =>
                          setState(() => _notifyResidents = v),
                      activeTrackColor: DesignColors.primary,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: DesignComponents.primaryButtonStyle,
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_notifyResidents
                          ? 'Send Notice'
                          : 'Save Notice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
