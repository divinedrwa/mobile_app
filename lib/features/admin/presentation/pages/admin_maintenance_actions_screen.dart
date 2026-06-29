import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';

/// Dedicated admin-only hub for all maintenance management actions.
///
/// Each tile leads to a distinct screen. No duplicates.
class AdminMaintenanceActionsScreen extends ConsumerWidget {
  const AdminMaintenanceActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Maintenance actions',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _ActionCard(
            icon: Icons.payments_outlined,
            color: DesignColors.accent,
            title: 'Maintenance hub',
            subtitle:
                'Mark payments, add/deduct credit, edit amounts, apply advance credit — all per-villa actions',
            onTap: () {
              HapticFeedback.lightImpact();
              context.go('/resident/admin-mark-payment');
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionCard(
            icon: Icons.money_off_rounded,
            color: DesignColors.error,
            title: 'Outstanding dues',
            subtitle:
                'Cross-cycle view of all villas with unpaid maintenance dues',
            onTap: () {
              HapticFeedback.lightImpact();
              context.go('/resident/admin-outstanding-dues');
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          // Tip card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              border: Border.all(color: const Color(0xFFBAE6FD)),
              borderRadius: BorderRadius.circular(DesignRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 18, color: Color(0xFF0369A1)),
                    const SizedBox(width: 8),
                    Text(
                      'Quick actions in the hub',
                      style: DesignTypography.bodySmall.copyWith(
                        color: const Color(0xFF0C4A6E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _tipLine('Tap "Actions" on a pending villa to record payment, add or deduct credit'),
                _tipLine('Long-press any villa row to edit amounts or view payment history'),
                _tipLine('Use checkboxes + "Send reminder" to nudge selected residents'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('  •  ', style: TextStyle(color: Color(0xFF0369A1))),
          Expanded(
            child: Text(
              text,
              style: DesignTypography.caption.copyWith(
                color: const Color(0xFF0C4A6E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        border: Border.all(color: DesignColors.borderLight),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DesignRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: DesignTypography.bodyMedium.copyWith(
                          color: DesignColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: DesignTypography.caption.copyWith(
                          color: DesignColors.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: DesignColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
