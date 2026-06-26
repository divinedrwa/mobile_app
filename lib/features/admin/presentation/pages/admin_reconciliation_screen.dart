import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for financial reconciliation and alerts.
class AdminReconciliationScreen extends ConsumerStatefulWidget {
  const AdminReconciliationScreen({super.key});

  @override
  ConsumerState<AdminReconciliationScreen> createState() =>
      _AdminReconciliationScreenState();
}

class _AdminReconciliationScreenState
    extends ConsumerState<AdminReconciliationScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminReconciliationSummaryProvider);
    ref.invalidate(adminReconciliationAlertsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminReconciliationSummaryProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Reconciliation',
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
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: summaryAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: [
                  ShimmerBox(height: 80, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(
                          height: 64, borderRadius: DesignRadius.lg),
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load reconciliation',
                  subtitle: 'Something went wrong. Please try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (summary) => _buildBody(summary),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> summary) {
    final alertsAsync = ref.watch(adminReconciliationAlertsProvider);
    // Backend nests this under `financialHealth.status` — reading the old
    // top-level `healthStatus` always fell through to "HEALTHY".
    final health =
        (summary['financialHealth'] as Map?) ?? const <String, dynamic>{};
    final healthStatus =
        health['status']?.toString().toUpperCase() ?? 'HEALTHY';

    final healthColor = _healthColor(healthStatus);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Health banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: healthColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
            border: Border.all(color: healthColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(_healthIcon(healthStatus), color: healthColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Health: $healthStatus',
                      style: DesignTypography.label.copyWith(
                        color: healthColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _healthMessage(healthStatus),
                      style: DesignTypography.captionSmall.copyWith(
                        color: healthColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Alerts
        EnterpriseSectionHeader(title: 'Alerts'),
        const SizedBox(height: 8),
        alertsAsync.when(
          loading: () => ShimmerWrap(
            child: Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      ShimmerBox(height: 64, borderRadius: DesignRadius.lg),
                ),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (alerts) {
            if (alerts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyStateWidget(
                  icon: Icons.check_circle_outline,
                  title: 'All clear',
                  subtitle: 'No reconciliation alerts at this time.',
                  iconColor: DesignColors.primary,
                ),
              );
            }
            return Column(
              children: alerts.asMap().entries.map((e) => _alertCard(e.value, e.key)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _alertCard(Map<String, dynamic> alert, [int index = 0]) {
    final severity =
        alert['severity']?.toString().toUpperCase() ?? 'INFO';
    final id = alert['id']?.toString() ?? '';
    // Resolved state is `resolvedAt != null` (there is no `status` field), and
    // there is no `message` field — build one from the real alert numbers.
    final isResolved = alert['resolvedAt'] != null;
    double money(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    final inr = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final cycle = (alert['cycle'] as Map?) ?? const {};
    final cycleTitle =
        (cycle['title']?.toString().trim().isNotEmpty ?? false)
            ? cycle['title'].toString()
            : 'Billing cycle';
    final diff = money(alert['difference']);
    final message =
        '$cycleTitle · Villas ${inr.format(money(alert['villaSum']))} vs cash ${inr.format(money(alert['societyCash']))} · diff ${diff >= 0 ? '+' : ''}${inr.format(diff)}';

    final sevColor = _severityColor(severity);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onTap: isResolved ? null : () => _showResolveSheet(id),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _severityIcon(severity),
              color: sevColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        severity,
                        style: DesignTypography.captionSmall.copyWith(
                          color: sevColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (isResolved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DesignColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RESOLVED',
                          style: DesignTypography.captionSmall.copyWith(
                            color: DesignColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: DesignTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isResolved)
            Icon(Icons.chevron_right,
                size: 18, color: DesignColors.textTertiary),
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  void _showResolveSheet(String id) {
    final notesCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                Text('Resolve Alert', style: DesignTypography.headingM),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Resolution notes',
                    hintText: 'Required — what was reconciled or corrected',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  // Notes are required server-side — keep Resolve disabled
                  // until something is entered (avoids a confusing 400).
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: notesCtrl,
                    builder: (_, value, __) {
                      final canResolve = value.text.trim().isNotEmpty;
                      return FilledButton(
                        onPressed: canResolve
                            ? () {
                                Navigator.pop(ctx);
                                _handleResolve(id, notesCtrl.text.trim());
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignColors.primary,
                        ),
                        child: const Text('Resolve'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleResolve(String id, String notes) async {
    try {
      await ref.read(adminReconciliationRepositoryProvider).resolveAlert(
            id,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert resolved')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  static Color _healthColor(String status) {
    switch (status) {
      case 'HEALTHY':
        return const Color(0xFF10B981);
      case 'WARNING':
        return const Color(0xFFF59E0B);
      case 'CRITICAL':
        return const Color(0xFFEF4444);
      default:
        return DesignColors.textSecondary;
    }
  }

  static IconData _healthIcon(String status) {
    switch (status) {
      case 'HEALTHY':
        return Icons.check_circle_outline;
      case 'WARNING':
        return Icons.warning_amber_rounded;
      case 'CRITICAL':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  static String _healthMessage(String status) {
    switch (status) {
      case 'HEALTHY':
        return 'All financial records are in order.';
      case 'WARNING':
        return 'Some discrepancies detected. Review alerts below.';
      case 'CRITICAL':
        return 'Significant issues found. Immediate action needed.';
      default:
        return 'Financial status check complete.';
    }
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case 'HIGH':
      case 'CRITICAL':
        return const Color(0xFFEF4444);
      case 'MEDIUM':
      case 'WARNING':
        return const Color(0xFFF59E0B);
      case 'LOW':
      case 'INFO':
        return const Color(0xFF3B82F6);
      default:
        return DesignColors.textSecondary;
    }
  }

  static IconData _severityIcon(String severity) {
    switch (severity) {
      case 'HIGH':
      case 'CRITICAL':
        return Icons.error_outline;
      case 'MEDIUM':
      case 'WARNING':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }
}
