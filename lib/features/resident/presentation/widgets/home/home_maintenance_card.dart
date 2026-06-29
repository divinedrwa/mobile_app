import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/theme/semantic_colors.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import 'home_shared.dart';
import 'home_skeletons.dart';

const EdgeInsets _kInnerPanelMargin = EdgeInsets.fromLTRB(14, 12, 14, 14);
const double _kInnerPanelRadius = 14;

enum _MaintenanceDueState { caughtUp, dueSoon, overdue }

DueVisualState _toVisualState(_MaintenanceDueState state) {
  switch (state) {
    case _MaintenanceDueState.overdue:
      return DueVisualState.overdue;
    case _MaintenanceDueState.dueSoon:
      return DueVisualState.dueSoon;
    case _MaintenanceDueState.caughtUp:
      return DueVisualState.caughtUp;
  }
}

class _MaintenanceShellStyle {
  const _MaintenanceShellStyle({
    required this.dueState,
    required this.palette,
  });

  final _MaintenanceDueState dueState;
  final DueStatePalette palette;
}

_MaintenanceShellStyle _resolveShellStyle(List<MaintenanceDueModel>? pending) {
  if (pending == null || pending.isEmpty) {
    return _MaintenanceShellStyle(
      dueState: _MaintenanceDueState.caughtUp,
      palette: DueStatePalette.of(DueVisualState.caughtUp),
    );
  }

  final totalDue = pending.fold<double>(0, (sum, m) => sum + m.remainingDue);
  if (totalDue <= 0) {
    return _MaintenanceShellStyle(
      dueState: _MaintenanceDueState.caughtUp,
      palette: DueStatePalette.of(DueVisualState.caughtUp),
    );
  }

  DateTime? earliestDue;
  for (final item in pending) {
    if (earliestDue == null || item.dueDate.isBefore(earliestDue)) {
      earliestDue = item.dueDate;
    }
  }

  if (earliestDue != null && earliestDue.isBefore(DateTime.now())) {
    return _MaintenanceShellStyle(
      dueState: _MaintenanceDueState.overdue,
      palette: DueStatePalette.of(DueVisualState.overdue),
    );
  }

  return _MaintenanceShellStyle(
    dueState: _MaintenanceDueState.dueSoon,
    palette: DueStatePalette.of(DueVisualState.dueSoon),
  );
}

class HomeMaintenanceCard extends ConsumerWidget {
  const HomeMaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingMaintenanceProvider);
    final outstandingAsync = ref.watch(outstandingDuesProvider);

    if (pendingAsync.isLoading && pendingAsync.valueOrNull == null) {
      return const HomeMaintenanceCardSkeleton();
    }

    final shell = _resolveShellStyle(pendingAsync.valueOrNull);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shell.palette.shellTop,
            Colors.white,
          ],
          stops: const [0.0, 0.55],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.palette.shellBorder.withValues(alpha: 0.8)),
        boxShadow: homeCardShadow(0.045),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MaintenanceStatusHeader(
            pendingAsync: pendingAsync,
            dueState: shell.dueState,
          ),
          _MaintenanceInnerPanel(
            outstandingAsync: outstandingAsync,
            navIconColor: shell.palette.navIcon,
          ),
        ],
      ),
    );
  }
}

class _MaintenanceInnerPanel extends StatelessWidget {
  const _MaintenanceInnerPanel({
    required this.outstandingAsync,
    required this.navIconColor,
  });

  final AsyncValue<Map<String, dynamic>> outstandingAsync;
  final Color navIconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _kInnerPanelMargin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kInnerPanelRadius),
          border: Border.all(
            color: DesignColors.border.withValues(alpha: 0.95),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kInnerPanelRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MaintenanceNavRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Dues & history',
                subtitle: 'Bills, payments and credit balance',
                iconColor: navIconColor,
                onTap: () => context.push('/resident/maintenance'),
              ),
              const _MaintenanceNavDivider(),
              _MaintenanceNavRow(
                icon: Icons.show_chart_rounded,
                title: 'Trends & expenses',
                subtitle: 'Month-wise breakdowns & society spend',
                iconColor: navIconColor,
                onTap: () => context.push('/resident/maintenance-payment'),
              ),
              _MaintenanceOutstandingFooter(outstandingAsync: outstandingAsync),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceNavDivider extends StatelessWidget {
  const _MaintenanceNavDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66, right: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}

class _MaintenanceNavRow extends StatelessWidget {
  const _MaintenanceNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          DesignHaptics.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.28,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary.withValues(alpha: 0.92),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.text.tertiary.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceOutstandingFooter extends StatelessWidget {
  const _MaintenanceOutstandingFooter({required this.outstandingAsync});

  final AsyncValue<Map<String, dynamic>> outstandingAsync;

  @override
  Widget build(BuildContext context) {
    final warn = DueStatePalette.of(DueVisualState.dueSoon);

    return outstandingAsync.when(
      loading: () => ColoredBox(
        color: warn.alertSurface,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: ShimmerWrap(
            child: ShimmerBox(height: 16, borderRadius: DesignRadius.md),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        final villasCount =
            (data['villasWithDuesCount'] as num?)?.toInt() ?? 0;
        final totalOutstanding =
            (data['totalOutstanding'] as num?)?.toDouble() ?? 0;

        if (villasCount <= 0) return const SizedBox.shrink();

        final inr = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '\u20b9',
          decimalDigits: 0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 66, right: 14),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            Material(
              color: warn.alertSurface,
              child: InkWell(
                onTap: () {
                  DesignHaptics.selection();
                  context.push('/resident/maintenance-payment?tab=2');
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_2_outlined,
                        size: 18,
                        color: warn.accent.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '$villasCount villa${villasCount != 1 ? 's' : ''} ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: warn.accent.withValues(alpha: 0.95),
                                ),
                              ),
                              TextSpan(
                                text: 'with outstanding dues \u2022 ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: warn.accent.withValues(alpha: 0.78),
                                ),
                              ),
                              TextSpan(
                                text: inr.format(totalOutstanding),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: warn.accent.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: warn.accent.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MaintenanceStatusHeader extends StatelessWidget {
  const _MaintenanceStatusHeader({
    required this.pendingAsync,
    required this.dueState,
  });

  final AsyncValue<List<MaintenanceDueModel>> pendingAsync;
  final _MaintenanceDueState dueState;

  @override
  Widget build(BuildContext context) {
    return pendingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const _CaughtUpHeader(),
      data: (pending) {
        final totalDue =
            pending.fold<double>(0, (sum, m) => sum + m.remainingDue);
        if (totalDue <= 0) return const _CaughtUpHeader();
        return _DueHeader(
          pending: pending,
          totalDue: totalDue,
          dueState: dueState,
        );
      },
    );
  }
}

class _CaughtUpHeader extends StatelessWidget {
  const _CaughtUpHeader();

  @override
  Widget build(BuildContext context) {
    final palette = DueStatePalette.of(DueVisualState.caughtUp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.gradientTop, palette.gradientBottom],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: palette.accent,
                  size: 26,
                ),
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: palette.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\u2019re all caught up!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                    letterSpacing: -0.35,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No pending maintenance dues on your account',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: palette.accent.withValues(alpha: 0.58),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.assignment_turned_in_rounded,
            size: 48,
            color: palette.accent.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _DueHeader extends StatelessWidget {
  const _DueHeader({
    required this.pending,
    required this.totalDue,
    required this.dueState,
  });

  final List<MaintenanceDueModel> pending;
  final double totalDue;
  final _MaintenanceDueState dueState;

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 0,
    );

    DateTime? earliestDue;
    for (final item in pending) {
      if (earliestDue == null || item.dueDate.isBefore(earliestDue)) {
        earliestDue = item.dueDate;
      }
    }
    final now = DateTime.now();
    final count = pending.length;

    final palette = DueStatePalette.of(_toVisualState(dueState));
    final statusLabel = switch (dueState) {
      _MaintenanceDueState.overdue => 'Overdue',
      _MaintenanceDueState.dueSoon => 'Due soon',
      _MaintenanceDueState.caughtUp => 'Due',
    };

    final String scheduleLine;
    if (earliestDue == null) {
      scheduleLine = '$count pending bill${count != 1 ? 's' : ''}';
    } else if (earliestDue.isBefore(now)) {
      final overdueDays = now.difference(earliestDue).inDays;
      scheduleLine =
          '$count bill${count != 1 ? 's' : ''} \u2022 $overdueDays day${overdueDays == 1 ? '' : 's'} overdue';
    } else {
      final daysLeft = earliestDue.difference(now).inDays + 1;
      scheduleLine =
          '$count bill${count != 1 ? 's' : ''} \u2022 due ${DateFormat('dd MMM').format(earliestDue)} ($daysLeft day${daysLeft == 1 ? '' : 's'})';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          DesignHaptics.selection();
          context.push('/resident/maintenance/dues');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.gradientTop, palette.gradientBottom],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  dueState == _MaintenanceDueState.overdue
                      ? Icons.warning_amber_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: palette.accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            inr.format(totalDue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: palette.accent,
                              letterSpacing: -0.45,
                              height: 1.05,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: palette.accent,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scheduleLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color:
                            DesignColors.textSecondary.withValues(alpha: 0.95),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: palette.accent,
                borderRadius: BorderRadius.circular(20),
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    DesignHaptics.selection();
                    context.push('/resident/maintenance/dues');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text(
                      'Pay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
