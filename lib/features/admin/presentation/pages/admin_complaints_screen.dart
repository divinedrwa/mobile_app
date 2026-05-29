import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for viewing and managing all society complaints.
///
/// Shows a 30-day analytics summary hero, status filter chips, and
/// complaints grouped by status in collapsible sections. Each complaint
/// card supports a "Update Status" action via bottom sheet.
class AdminComplaintsScreen extends ConsumerStatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  ConsumerState<AdminComplaintsScreen> createState() =>
      _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends ConsumerState<AdminComplaintsScreen>
    with WidgetsBindingObserver {
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
      ref.invalidate(adminComplaintsProvider);
      ref.invalidate(complaintAnalyticsSummaryProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(adminComplaintsProvider);
    ref.invalidate(complaintAnalyticsSummaryProvider);
    try {
      await Future.wait([
        ref.read(adminComplaintsProvider.future),
        ref.read(complaintAnalyticsSummaryProvider.future),
      ]);
    } catch (e) {
      debugPrint('AdminComplaintsScreen._refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(adminComplaintsProvider);
    final summaryAsync = ref.watch(complaintAnalyticsSummaryProvider);
    final activeFilter = ref.watch(adminComplaintStatusFilterProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Society Complaints',
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
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // ── Summary hero ──
            _buildSummaryHero(summaryAsync),
            const SizedBox(height: AppSpacing.lg),

            // ── Filter chips ──
            _buildFilterChips(activeFilter),
            const SizedBox(height: AppSpacing.sm),
            AdminSearchField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              hint: 'Search by title, villa, category…',
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Complaints list ──
            _buildComplaintsList(complaintsAsync),
          ],
        ),
      ),
    );
  }

  // ── Summary hero card ───────────────────────────────────────────────

  Widget _buildSummaryHero(AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
      loading: () => Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: DesignColors.primaryGradient,
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: DesignColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DesignRadius.xl),
          border: Border.all(color: DesignColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: DesignColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Failed to load summary',
                style: DesignTypography.bodySmall
                    .copyWith(color: DesignColors.error),
              ),
            ),
          ],
        ),
      ),
      data: (data) {
        final summary =
            data['summary'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final total = (summary['totalComplaints'] as num?)?.toInt() ?? 0;
        final resolved = (summary['resolvedCount'] as num?)?.toInt() ?? 0;
        final inProgress =
            (summary['inProgressCount'] as num?)?.toInt() ?? 0;
        final pending = (summary['pendingCount'] as num?)?.toInt() ?? 0;
        final resolutionRate =
            (summary['resolutionRate'] as num?)?.toDouble() ?? 0;
        final avgTime =
            (summary['avgResolutionTime'] as num?)?.toDouble() ?? 0;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: DesignColors.primaryGradient,
            borderRadius: BorderRadius.circular(DesignRadius.xl),
            boxShadow: DesignElevation.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: total + resolution rate
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total complaints',
                          style: DesignTypography.headingL.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last 30 days',
                          style: DesignTypography.caption
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  // Resolution rate circle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: Center(
                      child: Text(
                        '${resolutionRate.round()}%',
                        style: DesignTypography.label.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Resolution progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: resolutionRate / 100,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),

              // Bottom stat pills
              Row(
                children: [
                  _statPill('Open', pending, Colors.white),
                  const SizedBox(width: 8),
                  _statPill('In Progress', inProgress, Colors.white),
                  const SizedBox(width: 8),
                  _statPill('Resolved', resolved, Colors.white),
                  const Spacer(),
                  Text(
                    'Avg ${avgTime.toStringAsFixed(1)}d',
                    style: DesignTypography.caption
                        .copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: DesignTypography.captionSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────────

  Widget _buildFilterChips(String? activeFilter) {
    const filters = <String?, String>{
      null: 'All',
      'OPEN': 'Open',
      'IN_PROGRESS': 'In Progress',
      'RESOLVED': 'Resolved',
      'CLOSED': 'Closed',
    };

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = filters.entries.elementAt(index);
          final isSelected = activeFilter == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: isSelected,
            onSelected: (_) {
              ref.read(adminComplaintStatusFilterProvider.notifier).state =
                  entry.key;
            },
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
              borderRadius: BorderRadius.circular(DesignRadius.full),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  // ── Complaints list grouped by status ───────────────────────────────

  Widget _buildComplaintsList(AsyncValue<Map<String, dynamic>> async) {
    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ShimmerWrap(
          child: Column(
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ShimmerBox(height: 80, borderRadius: DesignRadius.md),
            )),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load complaints',
          subtitle: 'Pull down to refresh or try again',
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      ),
      data: (data) {
        final complaints =
            (data['complaints'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        if (complaints.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.check_circle_outline,
              title: 'No complaints found',
              subtitle: 'All complaints will appear here',
              iconColor: DesignColors.primary,
            ),
          );
        }

        // Apply search filter.
        final searchedComplaints = _searchQuery.isEmpty
            ? complaints
            : complaints.where((c) {
                final title = (c['title'] ?? '').toString().toLowerCase();
                final category = (c['category'] ?? '').toString().toLowerCase();
                final villa = (c['villa'] as Map<String, dynamic>?)?['villaNumber']?.toString().toLowerCase() ?? '';
                final owner = (c['villa'] as Map<String, dynamic>?)?['ownerName']?.toString().toLowerCase() ?? '';
                return title.contains(_searchQuery) ||
                    category.contains(_searchQuery) ||
                    villa.contains(_searchQuery) ||
                    owner.contains(_searchQuery);
              }).toList();

        if (searchedComplaints.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.search_off,
              title: 'No matches',
              subtitle: 'No complaints match your search.',
              iconColor: DesignColors.textTertiary,
            ),
          );
        }

        // Group complaints by status.
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final c in searchedComplaints) {
          final status = c['status']?.toString() ?? 'OPEN';
          (grouped[status] ??= []).add(c);
        }

        // Define display order.
        const order = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
        final sections = <Widget>[];
        for (final status in order) {
          final items = grouped[status];
          if (items == null || items.isEmpty) continue;
          sections.add(
            Padding(
              padding: EdgeInsets.only(top: sections.isEmpty ? 0 : 12),
              child: _CollapsibleGroup(
                label: _statusLabel(status),
                count: items.length,
                initiallyOpen: status == 'OPEN' || status == 'IN_PROGRESS',
                child: Column(
                  children: items.map((c) => _complaintCard(c)).toList(),
                ),
              ),
            ),
          );
        }

        return Column(children: sections);
      },
    );
  }

  // ── Individual complaint card ───────────────────────────────────────

  Widget _complaintCard(Map<String, dynamic> complaint) {
    final title = complaint['title']?.toString() ?? 'Untitled';
    final category = complaint['category']?.toString() ?? '';
    final status = complaint['status']?.toString() ?? 'OPEN';
    final adminNotes = complaint['adminNotes']?.toString();
    final createdAt = DateTime.tryParse(complaint['createdAt']?.toString() ?? '');
    final villa = complaint['villa'] as Map<String, dynamic>?;
    final villaNumber = villa?['villaNumber']?.toString() ?? '';
    final ownerName = villa?['ownerName']?.toString() ?? '';
    final block = villa?['block']?.toString() ?? '';

    final villaLabel = [
      if (villaNumber.isNotEmpty) villaNumber,
      if (block.isNotEmpty) block,
    ].join(', ');

    final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';
    final urgency = _urgencyLevel(status, createdAt);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with urgency badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _statusIcon(status),
                size: 18,
                color: _statusColor(status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: DesignTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (urgency != null) ...[
                const SizedBox(width: 8),
                _urgencyBadge(urgency),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Villa + owner + time
          Row(
            children: [
              const SizedBox(width: 26), // align with title
              if (villaLabel.isNotEmpty) ...[
                const Icon(Icons.home_outlined,
                    size: 13, color: DesignColors.textTertiary),
                const SizedBox(width: 3),
                Text(
                  villaLabel,
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textSecondary),
                ),
              ],
              if (ownerName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    ownerName,
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (timeAgo.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  timeAgo,
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textTertiary),
                ),
              ],
            ],
          ),

          // Category + action row
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 26),
              if (category.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DesignColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category,
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(DesignRadius.sm),
                onTap: () => _showUpdateSheet(complaint),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DesignColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  ),
                  child: Text(
                    'Update Status',
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Admin notes preview
          if (adminNotes != null && adminNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'Note: $adminNotes',
                style: DesignTypography.captionSmall.copyWith(
                  color: DesignColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUpdateSheet(Map<String, dynamic> complaint) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateStatusSheet(
        complaint: complaint,
        onUpdated: _refresh,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      default:
        return status;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'OPEN':
        return Icons.error_outline;
      case 'IN_PROGRESS':
        return Icons.timelapse;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'CLOSED':
        return Icons.archive_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return DesignColors.warning;
      case 'IN_PROGRESS':
        return DesignColors.info;
      case 'RESOLVED':
        return DesignColors.primary;
      case 'CLOSED':
        return DesignColors.textTertiary;
      default:
        return DesignColors.textSecondary;
    }
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  /// Returns urgency label for OPEN/IN_PROGRESS complaints only.
  static String? _urgencyLevel(String status, DateTime? createdAt) {
    if (createdAt == null) return null;
    if (status != 'OPEN' && status != 'IN_PROGRESS') return null;
    final days = DateTime.now().difference(createdAt).inDays;
    if (days > 7) return 'CRITICAL';
    if (days > 3) return 'HIGH';
    return null;
  }

  Widget _urgencyBadge(String urgency) {
    final isCritical = urgency == 'CRITICAL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isCritical
            ? DesignColors.error.withValues(alpha: 0.12)
            : DesignColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        urgency,
        style: DesignTypography.captionSmall.copyWith(
          color: isCritical ? DesignColors.error : DesignColors.warning,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Collapsible group (same pattern as admin maintenance hub)
// ═══════════════════════════════════════════════════════════════════════

class _CollapsibleGroup extends StatefulWidget {
  const _CollapsibleGroup({
    required this.label,
    required this.count,
    required this.child,
    this.initiallyOpen = true,
  });

  final String label;
  final int count;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<_CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<_CollapsibleGroup> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: DesignTypography.bodyMedium.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DesignColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: DesignTypography.caption.copyWith(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: DesignColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: widget.child,
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Update Status Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _UpdateStatusSheet extends ConsumerStatefulWidget {
  const _UpdateStatusSheet({
    required this.complaint,
    required this.onUpdated,
  });

  final Map<String, dynamic> complaint;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends ConsumerState<_UpdateStatusSheet> {
  late String _selectedStatus;
  final _notesController = TextEditingController();
  bool _submitting = false;

  static const _statuses = <String, String>{
    'OPEN': 'Open',
    'IN_PROGRESS': 'In Progress',
    'RESOLVED': 'Resolved',
    'CLOSED': 'Closed',
  };

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.complaint['status']?.toString() ?? 'OPEN';
    _notesController.text = widget.complaint['adminNotes']?.toString() ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final repo = ref.read(adminComplaintRepositoryProvider);
      await repo.updateComplaintStatus(
        widget.complaint['id']?.toString() ?? '',
        status: _selectedStatus,
        adminNotes:
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complaint updated to ${_statuses[_selectedStatus] ?? _selectedStatus}',
          ),
          backgroundColor: DesignColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
        ),
      );
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e, 'Update failed')),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.complaint['title']?.toString() ?? 'Complaint';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
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

            // Title
            Text(
              'Update Status',
              style: DesignTypography.headingM,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: DesignTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Status dropdown
            Text('Status', style: DesignTypography.label),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: DesignComponents.inputDecoration(
                hint: 'Select status',
              ),
              items: _statuses.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: DesignTypography.body),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedStatus = v);
              },
            ),
            const SizedBox(height: 16),

            // Admin notes
            Text('Admin Notes (optional)', style: DesignTypography.label),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: DesignComponents.inputDecoration(
                hint: 'Add a note for the resident...',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Submit button
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
                    : const Text('Confirm Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
