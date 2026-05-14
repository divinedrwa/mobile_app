import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../providers/visitor_provider.dart';

/// Poll / inbox: gate visitors waiting on your flat's approval.
class VisitorApprovalRequestsScreen extends ConsumerStatefulWidget {
  const VisitorApprovalRequestsScreen({super.key});

  @override
  ConsumerState<VisitorApprovalRequestsScreen> createState() =>
      _VisitorApprovalRequestsScreenState();
}

class _VisitorApprovalRequestsScreenState
    extends ConsumerState<VisitorApprovalRequestsScreen> {
  String _filter = 'pending';
  bool _acting = false;

  Future<void> _applyDecision({
    required String visitorId,
    required bool approve,
  }) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final repo = ref.read(visitorRepositoryProvider);
      if (approve) {
        await repo.approveVisitorRequest(visitorId);
      } else {
        await repo.rejectVisitorRequest(visitorId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Visitor approved.' : 'Visitor rejected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(visitorApprovalRequestsProvider('pending'));
      ref.invalidate(visitorApprovalRequestsProvider('all'));
      ref.invalidate(visitorApprovalRequestsProvider('approved'));
      ref.invalidate(visitorApprovalRequestsProvider('rejected'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitorApprovalRequestsProvider(_filter));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: context.surface.defaultSurface,
        foregroundColor: context.text.primary,
        title: Text(
          'Gate visitor requests',
          style: DesignTypography.headingM.copyWith(fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: context.surface.defaultSurface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.s16,
                context.spacing.s12,
                context.spacing.s16,
                context.spacing.s12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChipPill(
                      label: 'Pending',
                      selected: _filter == 'pending',
                      accent: DesignColors.primary,
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipPill(
                      label: 'Approved',
                      selected: _filter == 'approved',
                      accent: DesignColors.success,
                      onTap: () => setState(() => _filter = 'approved'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipPill(
                      label: 'Rejected',
                      selected: _filter == 'rejected',
                      accent: DesignColors.error,
                      onTap: () => setState(() => _filter = 'rejected'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipPill(
                      label: 'All',
                      selected: _filter == 'all',
                      accent: DesignColors.textSecondary,
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading requests…',
                      style: DesignTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              error: (e, _) => Padding(
                padding: EdgeInsets.all(context.spacing.s16),
                child: EnterpriseInfoBanner(
                  icon: Icons.wifi_tethering_error_rounded,
                  title: 'Could not load gate requests',
                  message: userFacingMessage(
                    e,
                    'Check your connection and try again.',
                  ),
                  tone: EnterpriseTone.danger,
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(visitorApprovalRequestsProvider(_filter)),
                ),
              ),
              data: (rows) => RefreshIndicator(
                color: DesignColors.primary,
                onRefresh: () async {
                  ref.invalidate(visitorApprovalRequestsProvider(_filter));
                  await ref.read(visitorApprovalRequestsProvider(_filter).future);
                },
                child: rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          context.spacing.s16,
                          context.spacing.s16,
                          context.spacing.s16,
                          context.spacing.s32,
                        ),
                        children: [
                          EmptyStateWidget(
                            icon: Icons.inbox_rounded,
                            title: _emptyTitle(_filter),
                            subtitle: _emptySubtitle(_filter),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          context.spacing.s16,
                          context.spacing.s16,
                          context.spacing.s16,
                          context.spacing.s32,
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: context.spacing.s12),
                        itemBuilder: (_, i) {
                          return _RequestCard(
                            data: rows[i],
                            onTap: (id) => context.push('/resident/visitor-requests/$id'),
                            actionBusy: _acting,
                            onApprove: (id) => _applyDecision(visitorId: id, approve: true),
                            onReject: (id) => _applyDecision(visitorId: id, approve: false),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _emptyTitle(String filter) {
    switch (filter) {
      case 'pending':
        return 'No pending requests';
      case 'approved':
        return 'No approved requests';
      case 'rejected':
        return 'No rejected requests';
      default:
        return 'No gate requests yet';
    }
  }

  String _emptySubtitle(String filter) {
    switch (filter) {
      case 'pending':
        return 'When security registers a visitor for your flat, you will see them here to approve or decline.';
      case 'approved':
        return 'Visitors you have approved for entry will appear here.';
      case 'rejected':
        return 'Requests you declined are listed here for your records.';
      default:
        return 'Pull down to refresh. Your society may not have any gate visits linked to your flat yet.';
    }
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.14) : DesignColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : DesignColors.borderLight,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 18, color: accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: selected ? accent : DesignColors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.data,
    required this.onTap,
    required this.actionBusy,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> data;
  final void Function(String id) onTap;
  final bool actionBusy;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String _typeLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Visitor';
    switch (raw.toUpperCase()) {
      case 'GUEST':
        return 'Guest';
      case 'DELIVERY':
        return 'Delivery';
      case 'SERVICE':
        return 'Service';
      case 'VENDOR':
        return 'Vendor';
      default:
        return raw.replaceAll('_', ' ').trim().isEmpty
            ? 'Visitor'
            : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
  }

  static _StatusUi _statusUi(String? status) {
    final s = (status ?? '').trim().toUpperCase();
    switch (s) {
      case 'PENDING_APPROVAL':
      case 'PENDING':
        return const _StatusUi(
          label: 'Pending approval',
          background: Color(0xFFFFF7ED),
          foreground: Color(0xFFC2410C),
          border: Color(0xFFFDBA74),
          icon: Icons.pending_actions_rounded,
        );
      case 'APPROVED':
        return const _StatusUi(
          label: 'Approved',
          background: Color(0xFFF0FDF4),
          foreground: Color(0xFF15803D),
          border: Color(0xFF86EFAC),
          icon: Icons.verified_rounded,
        );
      case 'CHECKED_IN':
        return const _StatusUi(
          label: 'On premises',
          background: Color(0xFFEFF6FF),
          foreground: Color(0xFF1D4ED8),
          border: Color(0xFF93C5FD),
          icon: Icons.home_work_rounded,
        );
      case 'REJECTED':
        return const _StatusUi(
          label: 'Declined',
          background: Color(0xFFFEF2F2),
          foreground: Color(0xFFB91C1C),
          border: Color(0xFFFECACA),
          icon: Icons.cancel_rounded,
        );
      case 'CHECKED_OUT':
        return const _StatusUi(
          label: 'Checked out',
          background: Color(0xFFF1F5F9),
          foreground: Color(0xFF475569),
          border: Color(0xFFCBD5E1),
          icon: Icons.logout_rounded,
        );
      default:
        if (s.isEmpty) {
          return const _StatusUi(
            label: 'Unknown',
            background: Color(0xFFF1F5F9),
            foreground: Color(0xFF64748B),
            border: Color(0xFFCBD5E1),
            icon: Icons.help_outline_rounded,
          );
        }
        final pretty = s.replaceAll('_', ' ').toLowerCase();
        return _StatusUi(
          label: pretty.isEmpty ? 'Unknown' : '${pretty[0].toUpperCase()}${pretty.substring(1)}',
          background: DesignColors.surfaceSoft,
          foreground: DesignColors.textSecondary,
          border: DesignColors.borderLight,
          icon: Icons.info_outline_rounded,
        );
    }
  }

  static IconData _typeIcon(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'DELIVERY':
        return Icons.local_shipping_outlined;
      case 'SERVICE':
        return Icons.build_outlined;
      case 'VENDOR':
        return Icons.storefront_outlined;
      case 'GUEST':
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = (data['name'] as String? ?? '').trim();
    final displayName = name.isEmpty ? 'Visitor' : name;
    final purpose = (data['purpose'] as String? ?? '').trim();
    final status = data['status'] as String?;
    final visitorType = data['visitorType'] as String?;
    final phone = (data['phone'] as String? ?? '').trim();
    final gate =
        (data['gate'] as Map?)?['name']?.toString().trim() ?? '';
    final arrived = _parseTime(data['checkInTime']) ??
        _parseTime(data['checkInAt']) ??
        _parseTime(data['createdAt']);
    final arrivedStr = arrived != null
        ? DateFormat('EEE, MMM d · h:mm a').format(arrived.toLocal())
        : null;

    final statusUi = _statusUi(status);
    final isPendingApproval = (status ?? '').trim().toUpperCase() == 'PENDING_APPROVAL';
    final typeLabel = _typeLabel(visitorType);
    final typeIcon = _typeIcon(visitorType);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: DesignColors.surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: DesignColors.borderLight),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: id.isEmpty ? null : () => onTap(id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DesignColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _initial(displayName),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: DesignColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.textPrimary,
                                height: 1.2,
                                letterSpacing: -0.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: DesignColors.textTertiary,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(
                            icon: typeIcon,
                            label: typeLabel,
                          ),
                          if (gate.isNotEmpty)
                            _MetaChip(
                              icon: Icons.door_front_door_outlined,
                              label: gate,
                            ),
                        ],
                      ),
                      if (arrivedStr != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: DesignColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Arrived · $arrivedStr',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: DesignColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 15,
                              color: DesignColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: DesignColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (purpose.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          purpose,
                          style: const TextStyle(
                            fontSize: 13,
                            color: DesignColors.textSecondary,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _StatusBadge(ui: statusUi),
                      if (isPendingApproval && id.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: actionBusy ? null : () => onApprove(id),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: DesignColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: actionBusy ? null : () => onReject(id),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: DesignColors.textPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusUi {
  const _StatusUi({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ui});

  final _StatusUi ui;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ui.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ui.icon, size: 16, color: ui.foreground),
          const SizedBox(width: 6),
          Text(
            ui.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ui.foreground,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignColors.textSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: DesignColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
