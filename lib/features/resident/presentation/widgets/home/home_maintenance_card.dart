import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';

class HomeMaintenanceCard extends ConsumerWidget {
  const HomeMaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingMaintenanceProvider);
    final outstandingAsync = ref.watch(outstandingDuesProvider);

    return Container(
      decoration: DesignComponents.cardDecoration(
        color: context.surface.defaultSurface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top: personal due status ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Maintenance',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusSection(context, pendingAsync),
              ],
            ),
          ),

          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),

          // ── Navigation shortcuts ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
            child: Column(
              children: [
                _navRow(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF43A047),
                  title: 'Dues & history',
                  subtitle: 'Bills, payments and credit balance',
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
                _navRow(
                  context,
                  icon: Icons.insights_rounded,
                  iconColor: DesignColors.primary,
                  title: 'Trends & expenses',
                  subtitle:
                      'Month-wise breakdowns & society spend',
                  onTap: () =>
                      context.push('/resident/maintenance-payment'),
                ),
              ],
            ),
          ),

          // ── Outstanding dues strip (society-wide) ──
          _buildOutstandingStrip(context, outstandingAsync),
        ],
      ),
    );
  }

  // ─── Personal due status ───────────────────────────────────────

  Widget _buildStatusSection(
    BuildContext context,
    AsyncValue<List<MaintenanceDueModel>> pendingAsync,
  ) {
    return pendingAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerWrap(
          child: ShimmerBox(height: 48, borderRadius: DesignRadius.md),
        ),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SizedBox.shrink(),
      ),
      data: (pending) {
        final inr = NumberFormat.currency(
            locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
        final totalDue =
            pending.fold<double>(0, (sum, m) => sum + m.remainingDue);
        final hasDue = totalDue > 0;

        if (!hasDue) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF16A34A)
                        .withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'You\u2019re all caught up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'No pending maintenance dues on your account',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.7),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Has dues
        final count = pending.length;
        DateTime? earliestDue;
        for (final item in pending) {
          if (earliestDue == null ||
              item.dueDate.isBefore(earliestDue)) {
            earliestDue = item.dueDate;
          }
        }
        final now = DateTime.now();

        final String statusLabel;
        final Color accent;
        final Color badgeBg;
        final Color badgeFg;

        if (earliestDue == null) {
          statusLabel = 'Due';
          accent = DesignColors.primary;
          badgeBg = DesignColors.primary.withValues(alpha: 0.12);
          badgeFg = DesignColors.primary;
        } else if (earliestDue.isBefore(now)) {
          statusLabel = 'Overdue';
          accent = DesignColors.error;
          badgeBg = const Color(0xFFFEE2E2);
          badgeFg = const Color(0xFFB91C1C);
        } else {
          statusLabel = 'Due soon';
          accent = const Color(0xFFD97706);
          badgeBg = const Color(0xFFFEF3C7);
          badgeFg = const Color(0xFFB45309);
        }

        final String scheduleLine;
        if (earliestDue == null) {
          scheduleLine = '$count bill${count != 1 ? 's' : ''}';
        } else if (earliestDue.isBefore(now)) {
          final overdueDays = now.difference(earliestDue).inDays;
          scheduleLine =
              '$count bill${count != 1 ? 's' : ''} \u00b7 $overdueDays day${overdueDays == 1 ? '' : 's'} overdue';
        } else {
          final daysLeft = earliestDue.difference(now).inDays + 1;
          scheduleLine =
              '$count bill${count != 1 ? 's' : ''} \u00b7 due ${DateFormat('dd MMM').format(earliestDue)} ($daysLeft day${daysLeft == 1 ? '' : 's'})';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              DesignHaptics.selection();
              context.push('/resident/maintenance/dues');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              inr.format(totalDue),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeFg,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          scheduleLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: context.text.secondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Pay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Outstanding dues strip (society-wide, compact) ────────────

  Widget _buildOutstandingStrip(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> outstandingAsync,
  ) {
    final data = outstandingAsync.valueOrNull;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final villasCount =
        (data['villasWithDuesCount'] as num?)?.toInt() ?? 0;
    final totalOutstanding =
        (data['totalOutstanding'] as num?)?.toDouble() ?? 0;

    if (villasCount <= 0) return const SizedBox.shrink();

    final inr = NumberFormat.currency(
        locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

    return Material(
      color: const Color(0xFFFEF2F2),
      child: InkWell(
        onTap: () {
          DesignHaptics.selection();
          // Outstanding tab is index 3
          context.push('/resident/maintenance-payment?tab=3');
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.groups_outlined,
                  size: 16,
                  color: DesignColors.error.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$villasCount villa${villasCount != 1 ? 's' : ''} ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: DesignColors.error
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      TextSpan(
                        text: 'with outstanding dues \u00b7 ',
                        style: TextStyle(
                          color: DesignColors.error
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      TextSpan(
                        text: inr.format(totalOutstanding),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: DesignColors.error
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: DesignColors.error.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Navigation row helper ─────────────────────────────────────

  Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              Icon(
                Icons.chevron_right_rounded,
                color:
                    DesignColors.textSecondary.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
