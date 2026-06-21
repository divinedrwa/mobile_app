import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_skeletons.dart';

class _VisitBreakdown {
  const _VisitBreakdown({
    required this.pendingResident,
    required this.rejected,
    required this.other,
  });

  final int pendingResident;
  final int rejected;
  final int other;
}

_VisitBreakdown _visitBreakdown(List<GuardVisitorRow> rows) {
  var pendingResident = 0;
  var rejected = 0;
  var other = 0;
  for (final r in rows) {
    if (r.needsResidentApproval) {
      pendingResident++;
    } else if (r.entryDenied) {
      rejected++;
    } else {
      other++;
    }
  }
  return _VisitBreakdown(
    pendingResident: pendingResident,
    rejected: rejected,
    other: other,
  );
}

class _OutcomeLineData {
  const _OutcomeLineData({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
}

List<BoxShadow> _summaryPageCardShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.035),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
  ];
}

/// Full-screen breakdown of today's metrics (from dashboard API + today's activity).
class GuardTodaySummaryPage extends ConsumerWidget {
  const GuardTodaySummaryPage({super.key});

  Future<void> _refreshAll(WidgetRef ref) async {
    Future<void> safe(Future<void> f) async {
      try {
        await f;
      } catch (_) {}
    }

    await Future.wait([
      safe(ref.refresh(guardDashboardProvider.future)),
      safe(ref.refresh(guardTodayVisitorsProvider.future)),
      safe(ref.refresh(guardPendingVisitorsProvider.future)),
      safe(ref.refresh(guardPreApprovedEntriesProvider.future)),
      safe(ref.refresh(guardPendingParcelsProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dash = ref.watch(guardDashboardProvider);
    final today = ref.watch(guardTodayVisitorsProvider);
    final pendV = ref.watch(guardPendingVisitorsProvider);
    final preApp = ref.watch(guardPreApprovedEntriesProvider);
    final pendP = ref.watch(guardPendingParcelsProvider);

    final pendingVisitors = pendV.maybeWhen(data: (l) => l.length, orElse: () => null);
    final preApproved = preApp.maybeWhen(data: (l) => l.length, orElse: () => null);
    final pendParcels = pendP.maybeWhen(data: (l) => l.length, orElse: () => null);
    final combinedPendingVisitors = pendingVisitors != null && preApproved != null
        ? pendingVisitors + preApproved
        : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Today's summary",
          style: GuardTokens.headingStyle(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _refreshAll(ref),
        child: dash.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              GuardSummarySkeleton(),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(GuardTokens.padScreen),
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top + 32),
              Icon(Icons.signal_wifi_bad_rounded, size: 48, color: scheme.error),
              const SizedBox(height: GuardTokens.g2),
              Text(
                userFacingMessage(e, 'Could not load summary.'),
                style: GuardTokens.bodyStyle(context),
              ),
              const SizedBox(height: GuardTokens.g3),
              FilledButton(
                onPressed: () => ref.invalidate(guardDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (d) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: GuardTokens.padScreen,
              right: GuardTokens.padScreen,
              top: GuardTokens.g1,
              bottom: GuardTokens.padScreen + 24,
            ),
            children: [
              Text(
                'Snapshot for your gate',
                style: GuardTokens.captionStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _SummaryGrid(stats: d.todayStats, isDark: Theme.of(context).brightness == Brightness.dark),
              const SizedBox(height: 14),
              if (combinedPendingVisitors != null && pendParcels != null)
                _PendingBanner(
                  visitors: combinedPendingVisitors,
                  parcels: pendParcels,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                )
              else if (pendV.hasError || preApp.hasError || pendP.hasError)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                    color: GuardTokens.warningMuted,
                    border: Border.all(
                      color: GuardTokens.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(GuardTokens.g2),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_problem_rounded, color: GuardTokens.warning),
                        const SizedBox(width: GuardTokens.g2),
                        Expanded(
                          child: Text(
                            'Could not load pending queue counts.',
                            style: GuardTokens.bodyStyle(context),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(guardPendingVisitorsProvider);
                            ref.invalidate(guardPreApprovedEntriesProvider);
                            ref.invalidate(guardPendingParcelsProvider);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: GuardTokens.g2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: GuardTokens.g2),
                      Expanded(
                        child: Text(
                          'Loading pending queue…',
                          style: GuardTokens.captionStyle(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'Visitor approvals & outcomes',
                style: GuardTokens.headingStyle(context).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Based on today’s activity log',
                style: GuardTokens.captionStyle(context).copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              today.when(
                loading: () => const ShimmerWrap(
                  child: ShimmerBox(
                    height: 180,
                    borderRadius: GuardTokens.radiusCard,
                  ),
                ),
                error: (e, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                    color: GuardTokens.warningMuted,
                    border: Border.all(color: GuardTokens.warning.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(GuardTokens.g3),
                    child: Row(
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, color: GuardTokens.warning),
                        const SizedBox(width: GuardTokens.g2),
                        Expanded(
                          child: Text(
                            userFacingMessage(e, 'Could not load visit breakdown.'),
                            style: GuardTokens.bodyStyle(context),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(guardTodayVisitorsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (rows) {
                  final b = _visitBreakdown(rows);
                  final s = d.todayStats.visitors;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (rows.isNotEmpty && s != rows.length)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Dashboard total: $s · Log entries: ${rows.length}',
                            style: GuardTokens.captionStyle(context).copyWith(height: 1.35),
                          ),
                        ),
                      _VisitorOutcomeCard(
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        rows: [
                          _OutcomeLineData(
                            icon: Icons.groups_rounded,
                            label: 'Total (activity log)',
                            value: '${rows.length}',
                            accent: GuardTokens.guardAccent,
                          ),
                          _OutcomeLineData(
                            icon: Icons.pending_actions_rounded,
                            label: 'Awaiting resident response',
                            value: '${b.pendingResident}',
                            accent: GuardTokens.warning,
                          ),
                          _OutcomeLineData(
                            icon: Icons.cancel_rounded,
                            label: 'Rejected / denied',
                            value: '${b.rejected}',
                            accent: GuardTokens.warning,
                          ),
                          _OutcomeLineData(
                            icon: Icons.verified_rounded,
                            label: 'Cleared through gate workflow',
                            value: '${b.other}',
                            accent: GuardTokens.success,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Pull down to refresh all figures.',
                textAlign: TextAlign.center,
                style: GuardTokens.captionStyle(context).copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.stats,
    required this.isDark,
  });

  final GuardTodayStats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard(
          label: 'Visitors',
          value: stats.visitors,
          icon: Icons.groups_rounded,
          accent: GuardTokens.guardAccent,
          isDark: isDark,
        ),
        _MetricCard(
          label: 'Deliveries',
          value: stats.parcels,
          icon: Icons.local_shipping_rounded,
          accent: GuardTokens.success,
          isDark: isDark,
        ),
        _MetricCard(
          label: 'Patrols',
          value: stats.patrols,
          icon: Icons.directions_walk_rounded,
          accent: const Color(0xFF6366F1),
          isDark: isDark,
        ),
        _MetricCard(
          label: 'Incidents',
          value: stats.incidents,
          icon: Icons.shield_rounded,
          accent: GuardTokens.warning,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final tileW = (w - GuardTokens.padScreen * 2 - 10) / 2;
    final width = tileW.clamp(140.0, 420.0);
    return Semantics(
      label: '$value $label',
      child: Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        color: isDark ? GuardTokens.darkCard : Colors.white,
        border: Border.all(
          color: isDark
              ? GuardTokens.darkBorder.withValues(alpha: 0.85)
              : GuardTokens.borderSubtle.withValues(alpha: 0.9),
        ),
        boxShadow: isDark ? null : _summaryPageCardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.05,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GuardTokens.captionStyle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
}

class _VisitorOutcomeCard extends StatelessWidget {
  const _VisitorOutcomeCard({
    required this.isDark,
    required this.rows,
  });

  final bool isDark;
  final List<_OutcomeLineData> rows;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? GuardTokens.darkBorder.withValues(alpha: 0.85)
        : GuardTokens.borderSubtle.withValues(alpha: 0.9);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        color: isDark ? GuardTokens.darkCard : Colors.white,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : _summaryPageCardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withValues(alpha: 0.65),
              ),
            _OutcomeRow(line: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({required this.line});

  final _OutcomeLineData line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(line.icon, color: line.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.label,
              style: GuardTokens.bodyStyle(context).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
          Text(
            line.value,
            style: GuardTokens.headingStyle(context).copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.visitors,
    required this.parcels,
    required this.isDark,
  });

  final int visitors;
  final int parcels;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (visitors == 0 && parcels == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
          color: isDark
              ? GuardTokens.darkCard
              : GuardTokens.success.withValues(alpha: 0.06),
          border: Border.all(
            color: GuardTokens.success.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: GuardTokens.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No pending approvals or parcels.',
                style: GuardTokens.bodyStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final parts = <String>[
      if (visitors > 0)
        '$visitors in queue (visitors + pre-approved)',
      if (parcels > 0)
        '$parcels parcel${parcels == 1 ? '' : 's'} pending',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        color: isDark
            ? const Color(0xFF422006).withValues(alpha: 0.85)
            : GuardTokens.warningMuted.withValues(alpha: 0.75),
        border: Border.all(
          color: GuardTokens.warning.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: GuardTokens.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.pending_actions_rounded,
              color: GuardTokens.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awaiting action',
                  style: GuardTokens.headingStyle(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  parts.join(' · '),
                  style: GuardTokens.captionStyle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
