import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../widgets/list_skeleton.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../providers/visitor_provider.dart';
import '../widgets/visitor_management_ui.dart';

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
  // Visitor ids with a decision in flight. Per-id (not a single flag) so acting
  // on one request doesn't freeze the others and errors can't attach to the
  // wrong card.
  final Set<String> _actingIds = <String>{};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _syncPoll();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _syncPoll() {
    if (_filter == 'pending') {
      _poll ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        // Don't reload the list from under a decision that's in flight — it can
        // re-order/remove the card the user is acting on.
        if (_actingIds.isNotEmpty) return;
        ref.invalidate(visitorApprovalRequestsProvider('pending'));
      });
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _setFilter(String filter) {
    setState(() => _filter = filter);
    _syncPoll();
  }

  Future<void> _applyDecision({
    required String visitorId,
    required bool approve,
  }) async {
    if (_actingIds.contains(visitorId)) return;
    setState(() => _actingIds.add(visitorId));
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
      if (mounted) setState(() => _actingIds.remove(visitorId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitorApprovalRequestsProvider(_filter));

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surface.defaultSurface,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gate visitor requests',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            Text(
              'Approve or reject gate entry requests',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.text.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
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
                      onTap: () => _setFilter('pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipPill(
                      label: 'Approved',
                      selected: _filter == 'approved',
                      accent: DesignColors.success,
                      onTap: () => _setFilter('approved'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipPill(
                      label: 'Rejected',
                      selected: _filter == 'rejected',
                      accent: DesignColors.error,
                      onTap: () => _setFilter('rejected'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipPill(
                      label: 'All',
                      selected: _filter == 'all',
                      accent: DesignColors.textSecondary,
                      onTap: () => _setFilter('all'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const ListSkeleton(itemHeight: 100),
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
                          final rowId = rows[i]['id'] as String? ?? '';
                          return _RequestCard(
                            data: rows[i],
                            onTap: (id) => context.push('/resident/visitor-requests/$id'),
                            actionBusy: _actingIds.contains(rowId),
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
      case 'SERVICE_PROVIDER':
        return 'Service';
      case 'VENDOR':
        return 'Vendor';
      default:
        return raw.replaceAll('_', ' ').trim().isEmpty
            ? 'Visitor'
            : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
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

    final statusRaw = status ?? '';
    final isPendingApproval =
        statusRaw.trim().toUpperCase() == 'PENDING_APPROVAL';
    final typeLabel = _typeLabel(visitorType);
    final typeIcon = _typeIcon(visitorType);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: DesignColors.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: DesignColors.borderLight),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: id.isEmpty ? null : () => onTap(id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VisitorMgmtAvatar(name: displayName),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: DesignColors.textPrimary,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: DesignColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    VisitorMgmtStatusChip(statusRaw: statusRaw),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: DesignColors.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    VisitorMgmtMetaChip(icon: typeIcon, label: typeLabel),
                    if (gate.isNotEmpty)
                      VisitorMgmtMetaChip(
                        icon: Icons.door_front_door_outlined,
                        label: gate,
                      ),
                    if (arrivedStr != null)
                      VisitorMgmtMetaChip(
                        icon: Icons.schedule_rounded,
                        label: 'Arrived · $arrivedStr',
                        maxWidth: 260,
                      ),
                    if (purpose.isNotEmpty)
                      VisitorMgmtMetaChip(
                        icon: Icons.notes_rounded,
                        label: purpose,
                        maxWidth: 280,
                      ),
                  ],
                ),
                if (isPendingApproval && id.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}
