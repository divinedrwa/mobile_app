import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/providers/maintenance_provider.dart';

class HomeMaintenanceCard extends ConsumerWidget {
  const HomeMaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstandingAsync = ref.watch(outstandingDuesProvider);
    final villasCount = outstandingAsync.whenOrNull(
      data: (d) =>
          (d['villasWithDuesCount'] as num?)?.toInt() ?? 0,
    );

    return Container(
      decoration: DesignComponents.cardDecoration(
        color: context.surface.defaultSurface,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Maintenance',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: -0.25,
              ),
            ),
          ),
          _maintenanceCardRow(
            context,
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF43A047),
            title: 'Dues, payments & credit',
            subtitle:
                'Pay open bills, view history and credit balance',
            onTap: () => context.push('/resident/maintenance'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          _maintenanceCardRow(
            context,
            icon: Icons.insights_rounded,
            iconColor: DesignColors.primary,
            title: 'Trends & expenses',
            subtitle:
                'Month-wise paid/unpaid, society spend, pending dues',
            onTap: () =>
                context.push('/resident/maintenance-payment'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          _maintenanceCardRow(
            context,
            icon: Icons.warning_amber_rounded,
            iconColor: DesignColors.error,
            title: 'Outstanding dues',
            subtitle: 'All pending payments across villas',
            onTap: () =>
                context.push('/resident/maintenance-payment'),
            trailingBadge:
                villasCount != null && villasCount > 0
                    ? villasCount
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _maintenanceCardRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? trailingBadge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          DesignHaptics.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingBadge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$trailingBadge',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: DesignColors.textSecondary
                    .withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
