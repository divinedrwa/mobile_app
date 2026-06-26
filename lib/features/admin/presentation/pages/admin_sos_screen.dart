import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/widgets/enterprise_ui.dart';

/// Admin screen for managing SOS alerts with lifecycle actions.
class AdminSosScreen extends ConsumerStatefulWidget {
  const AdminSosScreen({super.key});

  @override
  ConsumerState<AdminSosScreen> createState() => _AdminSosScreenState();
}

class _AdminSosScreenState extends ConsumerState<AdminSosScreen> {
  String? _statusFilter; // null = All

  static const _filterLabels = <String?, String>{
    null: 'All',
    'CREATED': 'New',
    'ACKNOWLEDGED': 'Acknowledged',
    'IN_PROGRESS': 'In Progress',
    'RESOLVED': 'Resolved',
    'CANCELLED': 'Cancelled',
  };

  Future<void> _refresh() async {
    ref.invalidate(adminSosStatsProvider);
    ref.invalidate(adminSosAlertsProvider(_statusFilter));
  }

  Future<void> _doAction(
      String id, String action, Future<void> Function(String) fn) async {
    try {
      await fn(id);
      ref.invalidate(adminSosStatsProvider);
      ref.invalidate(adminSosAlertsProvider(_statusFilter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('SOS $action successfully'),
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
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminSosStatsProvider);
    final alertsAsync = ref.watch(adminSosAlertsProvider(_statusFilter));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'SOS Alerts',
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
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Stats hero
            statsAsync.when(
              loading: () => _buildStatsLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => _buildStatsHero(stats),
            ),
            const SizedBox(height: 16),

            // Filter chips
            _buildFilterChips(),
            const SizedBox(height: 16),

            // Alerts list
            alertsAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(16),
                child: ShimmerWrap(
                  child: Column(
                    children: List.generate(4, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ShimmerBox(height: 90, borderRadius: DesignRadius.lg),
                    )),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load alerts',
                  subtitle: userFacingMessage(e),
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
              data: (data) => _buildAlertsList(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHero(Map<String, dynamic> stats) {
    final total = (stats['totalAlerts'] as num?)?.toInt() ?? 0;
    final active = (stats['activeAlerts'] as num?)?.toInt() ?? 0;
    final resolved = (stats['resolvedAlerts'] as num?)?.toInt() ?? 0;
    final avgAck = (stats['avgAcknowledgementSeconds'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: DesignElevation.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$active active',
                    style: DesignTypography.headingL
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('$total total \u00b7 $resolved resolved',
                    style:
                        DesignTypography.caption.copyWith(color: Colors.white70)),
                if (avgAck > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                      'Avg response: ${_formatSeconds(avgAck)}',
                      style: DesignTypography.captionSmall
                          .copyWith(color: Colors.white60)),
                ],
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsLoading() {
    return ShimmerWrap(
      child: ShimmerBox(height: 80, borderRadius: DesignRadius.xl),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = _filterLabels.entries.elementAt(index);
          final isSelected = _statusFilter == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _statusFilter = entry.key);
              ref.invalidate(adminSosAlertsProvider(entry.key));
            },
            selectedColor: const Color(0xFFDC2626),
            backgroundColor: DesignColors.surfaceSoft,
            labelStyle: DesignTypography.labelSmall.copyWith(
              color: isSelected ? Colors.white : DesignColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFFDC2626)
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

  Widget _buildAlertsList(Map<String, dynamic> data) {
    final alerts = (data['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (alerts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: EmptyStateWidget(
          icon: Icons.sos_rounded,
          title: 'No SOS alerts found',
          subtitle: 'All clear! There are no alerts matching the current filter.',
          iconColor: const Color(0xFFDC2626),
        ),
      );
    }

    return Column(children: alerts.asMap().entries.map((e) => _alertCard(e.value, e.key)).toList());
  }

  Widget _alertCard(Map<String, dynamic> alert, [int index = 0]) {
    final id = alert['id']?.toString() ?? '';
    final status = alert['status']?.toString() ?? 'CREATED';
    final type = alert['emergencyType']?.toString() ?? 'OTHER';
    final villa = alert['villa'] as Map<String, dynamic>?;
    final user = alert['user'] as Map<String, dynamic>?;
    final villaNumber = villa?['villaNumber']?.toString() ?? '';
    final userName = user?['name']?.toString() ?? user?['username']?.toString() ?? '';
    final createdAt = alert['createdAt']?.toString();
    final description = alert['description']?.toString();

    final typeConfig = _emergencyTypeConfig(type);
    final statusColor = _statusColor(status);

    final EnterpriseTone tone;
    switch (status) {
      case 'CREATED':
        tone = EnterpriseTone.danger;
        break;
      case 'ACKNOWLEDGED':
        tone = EnterpriseTone.info;
        break;
      case 'IN_PROGRESS':
        tone = EnterpriseTone.warning;
        break;
      case 'RESOLVED':
        tone = EnterpriseTone.success;
        break;
      default:
        tone = EnterpriseTone.neutral;
    }

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeConfig.icon, color: typeConfig.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(typeConfig.label,
                        style: DesignTypography.label
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      [
                        if (villaNumber.isNotEmpty) 'Villa $villaNumber',
                        if (userName.isNotEmpty) userName,
                        if (createdAt != null) _formatTime(createdAt),
                      ].join(' \u00b7 '),
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusLabel(status),
                  style: DesignTypography.captionSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description,
                style: DesignTypography.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          // Action buttons per status
          if (status == 'CREATED' ||
              status == 'ACKNOWLEDGED' ||
              status == 'IN_PROGRESS') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'CREATED')
                  _actionButton('Acknowledge', const Color(0xFF3B82F6), () {
                    _doAction(id, 'acknowledged',
                        ref.read(adminSosRepositoryProvider).acknowledgeSos);
                  }),
                if (status == 'ACKNOWLEDGED')
                  _actionButton('Start Response', DesignColors.warning, () {
                    _doAction(id, 'started',
                        ref.read(adminSosRepositoryProvider).startSos);
                  }),
                if (status == 'IN_PROGRESS')
                  _actionButton('Resolve', DesignColors.primary, () {
                    _doAction(id, 'resolved',
                        ref.read(adminSosRepositoryProvider).resolveSos);
                  }),
              ],
            ),
          ],
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(DesignRadius.full),
        ),
        child: Text(label,
            style: DesignTypography.labelSmall.copyWith(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'CREATED':
        return const Color(0xFFDC2626);
      case 'ACKNOWLEDGED':
        return const Color(0xFF3B82F6);
      case 'IN_PROGRESS':
        return DesignColors.warning;
      case 'RESOLVED':
        return DesignColors.primary;
      case 'CANCELLED':
        return DesignColors.textTertiary;
      default:
        return DesignColors.textSecondary;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'CREATED':
        return 'New';
      case 'ACKNOWLEDGED':
        return 'Acknowledged';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static _EmergencyType _emergencyTypeConfig(String type) {
    switch (type) {
      case 'MEDICAL':
        return const _EmergencyType(
            'Medical', Icons.medical_services_rounded, Color(0xFFDC2626));
      case 'FIRE':
        return const _EmergencyType(
            'Fire', Icons.local_fire_department_rounded, Color(0xFFF97316));
      case 'SECURITY':
        return const _EmergencyType(
            'Security', Icons.shield_rounded, Color(0xFF3B82F6));
      case 'ACCIDENT':
        return const _EmergencyType(
            'Accident', Icons.car_crash_rounded, Color(0xFFF59E0B));
      default:
        return const _EmergencyType(
            'Emergency', Icons.warning_amber_rounded, Color(0xFFDC2626));
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m';
    return '${(seconds / 3600).round()}h';
  }
}

class _EmergencyType {
  const _EmergencyType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
