import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin view of first-party mobile/web app usage (sessions, logins, screens).
class AdminAppAnalyticsScreen extends ConsumerWidget {
  const AdminAppAnalyticsScreen({super.key});

  String _fmtDuration(int ms) {
    if (ms <= 0) return '—';
    final m = (ms / 60000).floor();
    final s = ((ms % 60000) / 1000).floor();
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminAppAnalyticsSummaryProvider);
    final trendAsync = ref.watch(adminAppAnalyticsDailyTrendProvider);
    final screensAsync = ref.watch(adminAppAnalyticsScreensProvider);
    final flowsAsync = ref.watch(adminAppAnalyticsFlowsProvider);
    final actionsAsync = ref.watch(adminAppAnalyticsActionsProvider);
    final errorsAsync = ref.watch(adminAppAnalyticsErrorsProvider);
    final insightsAsync = ref.watch(adminAppAnalyticsInsightsProvider);
    final usersAsync = ref.watch(adminAppAnalyticsActiveUsersProvider);
    final engagementAsync = ref.watch(adminAppAnalyticsUserEngagementProvider);

    Future<void> refresh() async {
      ref.invalidate(adminAppAnalyticsSummaryProvider);
      ref.invalidate(adminAppAnalyticsDailyTrendProvider);
      ref.invalidate(adminAppAnalyticsScreensProvider);
      ref.invalidate(adminAppAnalyticsFlowsProvider);
      ref.invalidate(adminAppAnalyticsActionsProvider);
      ref.invalidate(adminAppAnalyticsErrorsProvider);
      ref.invalidate(adminAppAnalyticsInsightsProvider);
      ref.invalidate(adminAppAnalyticsActiveUsersProvider);
      ref.invalidate(adminAppAnalyticsUserEngagementProvider);
    }

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        title: Text(
          'App Usage',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: refresh,
        child: summaryAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ShimmerBox(height: 120, borderRadius: DesignRadius.xl),
              SizedBox(height: 12),
              ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load app analytics',
                  subtitle: e.toString(),
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: refresh,
                ),
              ),
            ],
          ),
          data: (summary) {
            final totals =
                (summary['totals'] as Map?)?.cast<String, dynamic>() ?? {};
            final push =
                (summary['pushDevices'] as Map?)?.cast<String, dynamic>() ?? {};
            final byPlatform = summary['byPlatform'] as List? ?? [];
            final byAppVersion = summary['byAppVersion'] as List? ?? [];
            final engagementSummary =
                (summary['engagement'] as Map?)?.cast<String, dynamic>() ?? {};
            final activeByRole = summary['activeUsersByRole'] as List? ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Usage is recorded on your server and mirrored to Firebase Analytics — all roles (resident, guard, admin).',
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _MetricGrid(
                  items: [
                    _Metric('Daily active', '${totals['dailyActiveUsers'] ?? 0}'),
                    _Metric('Weekly active', '${totals['weeklyActiveUsers'] ?? 0}'),
                    _Metric('Period active', '${totals['uniqueActiveUsers'] ?? 0}'),
                    _Metric('Logins (30d)', '${totals['logins'] ?? 0}'),
                    _Metric('Sessions', '${totals['sessions'] ?? 0}'),
                    _Metric('Screen views', '${totals['screenViews'] ?? 0}'),
                    _Metric('Business actions', '${totals['actions'] ?? 0}'),
                    _Metric('Flow completions', '${totals['flowCompletions'] ?? 0}'),
                    _Metric('Errors', '${totals['errors'] ?? 0}'),
                    _Metric(
                      'Stickiness (DAU/MAU)',
                      '${totals['stickinessPct'] ?? 0}%',
                    ),
                    _Metric(
                      'Avg session',
                      _fmtDuration(totals['avgSessionDurationMs'] as int? ?? 0),
                    ),
                    _Metric(
                      'Registered accounts',
                      '${totals['registeredAccounts'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Push devices (install proxy)'),
                _InfoCard(
                  children: [
                    _Row('Registered devices', '${push['registered'] ?? 0}'),
                    _Row('Active today', '${push['activeToday'] ?? 0}'),
                    _Row('Active this week', '${push['activeWeek'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Daily trend (14 days)'),
                trendAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load trend'),
                  data: (trend) {
                    if (trend.isEmpty) {
                      return const Text(
                        'No activity yet — data appears after users open the app.',
                      );
                    }
                    return _InfoCard(
                      children: trend
                          .map(
                            (d) => _Row(
                              d['displayDate']?.toString() ?? '',
                              'DAU ${d['activeUsers']} · ${d['logins']} logins',
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('User engagement (30 days)'),
                _InfoCard(
                  children: [
                    _Row('Active in period', '${engagementSummary['activeInPeriod'] ?? 0}'),
                    _Row('Inactive (dormant)', '${engagementSummary['inactiveInPeriod'] ?? 0}'),
                    _Row('Never opened app', '${engagementSummary['neverUsedApp'] ?? 0}'),
                    _Row('Deactivated accounts', '${engagementSummary['deactivatedAccounts'] ?? 0}'),
                  ],
                ),
                if (activeByRole.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Active users by role'),
                  _InfoCard(
                    children: activeByRole
                        .map(
                          (r) => _Row(
                            r['role']?.toString() ?? '',
                            '${r['count']}',
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionTitle('Platform breakdown'),
                _InfoCard(
                  children: byPlatform.isEmpty
                      ? [const Text('No sessions yet')]
                      : byPlatform
                          .map(
                            (p) => _Row(
                              p['platform']?.toString() ?? '',
                              '${p['sessionCount']} sessions',
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('App versions'),
                _InfoCard(
                  children: byAppVersion.isEmpty
                      ? [const Text('No version data yet')]
                      : byAppVersion
                          .map(
                            (v) => _Row(
                              v['appVersion']?.toString() ?? 'unknown',
                              '${v['sessionCount']} sessions',
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Growth insights'),
                insightsAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load insights'),
                  data: (insights) {
                    final stickiness =
                        (insights['stickiness'] as Map?)?.cast<String, dynamic>() ??
                            {};
                    final retention =
                        (insights['retention'] as Map?)?.cast<String, dynamic>() ??
                            {};
                    final peakHours = insights['peakHours'] as List? ?? [];
                    return _InfoCard(
                      children: [
                        _Row(
                          'Stickiness (DAU ÷ MAU)',
                          '${stickiness['stickinessPct'] ?? 0}%',
                        ),
                        _Row('Weekly ÷ Monthly', '${stickiness['wauMauPct'] ?? 0}%'),
                        _Row('7-day retention', '${retention['d7Pct'] ?? 0}%'),
                        _Row('30-day retention', '${retention['d30Pct'] ?? 0}%'),
                        if (peakHours.isNotEmpty)
                          _Row(
                            'Peak hour',
                            '${peakHours.first['label']} (${peakHours.first['count']} sessions)',
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Business actions (feature adoption)'),
                actionsAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load actions'),
                  data: (actions) => _InfoCard(
                    children: actions.isEmpty
                        ? [const Text('No business actions recorded yet')]
                        : actions
                            .take(12)
                            .map(
                              (a) => _Row(
                                a['label']?.toString() ?? a['action']?.toString() ?? '',
                                '${a['count']} · ${a['adoptionPct'] ?? 0}% adoption',
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Guard flows (completion & success)'),
                flowsAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load flows'),
                  data: (flows) => _InfoCard(
                    children: flows.isEmpty
                        ? [const Text('No guard flow completions yet')]
                        : flows
                            .take(12)
                            .map(
                              (f) => _Row(
                                f['flowId']?.toString().replaceAll('_', ' ') ?? '',
                                '${f['count']} · ${f['successRate'] ?? 0}% ok',
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Errors & reliability'),
                errorsAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load errors'),
                  data: (payload) {
                    final errors = payload['errors'] as List? ?? [];
                    final totals =
                        (payload['totals'] as Map?)?.cast<String, dynamic>() ?? {};
                    if (errors.isEmpty) {
                      return Text(
                        'No errors recorded · ${totals['errorRatePct'] ?? 0}% error rate',
                      );
                    }
                    return _InfoCard(
                      children: [
                        _Row('Error rate', '${totals['errorRatePct'] ?? 0}% of sessions'),
                        ...errors.take(8).map(
                              (e) => _Row(
                                e['error']?.toString() ?? '',
                                '${e['count']}×',
                              ),
                            ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Top screens'),
                screensAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load screens'),
                  data: (screens) => _InfoCard(
                    children: screens.isEmpty
                        ? [const Text('No screen views recorded yet')]
                        : screens
                            .take(12)
                            .map(
                              (s) => _Row(
                                s['screen']?.toString() ?? '',
                                '${s['views']} views',
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Inactive / never used'),
                engagementAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load engagement lists'),
                  data: (engagement) {
                    final inactive = engagement['inactiveUsers'] as List? ?? [];
                    final neverUsed = engagement['neverUsedUsers'] as List? ?? [];
                    if (inactive.isEmpty && neverUsed.isEmpty) {
                      return const Text('All registered users were active in this period.');
                    }
                    return _InfoCard(
                      children: [
                        if (inactive.isNotEmpty) ...[
                          Text(
                            'Dormant (${inactive.length})',
                            style: DesignTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: DesignColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...inactive.take(10).map(
                                (u) => _Row(
                                  '${u['name']} (${u['role']})',
                                  u['villaNumber']?.toString() ?? '—',
                                ),
                              ),
                        ],
                        if (neverUsed.isNotEmpty) ...[
                          if (inactive.isNotEmpty) const Divider(height: 20),
                          Text(
                            'Never used app (${neverUsed.length})',
                            style: DesignTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: DesignColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...neverUsed.take(10).map(
                                (u) => _Row(
                                  '${u['name']} (${u['role']})',
                                  u['username']?.toString() ?? '',
                                ),
                              ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Recently active users'),
                usersAsync.when(
                  loading: () =>
                      const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  error: (_, __) => const Text('Could not load users'),
                  data: (users) => _InfoCard(
                    children: users.isEmpty
                        ? [const Text('No recent sessions')]
                        : users
                            .take(15)
                            .map(
                              (u) => _Row(
                                '${u['name']} (${u['role']})',
                                u['lastSeenAt']?.toString().split('T').first ?? '',
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (m) => SizedBox(
              width: (MediaQuery.sizeOf(context).width - 42) / 2,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  side: BorderSide(color: DesignColors.border.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.value,
                        style: DesignTypography.headingM.copyWith(
                          fontWeight: FontWeight.w800,
                          color: DesignColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.label,
                        style: DesignTypography.bodySmall.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: DesignTypography.headingM.copyWith(
          fontWeight: FontWeight.w700,
          color: DesignColors.textPrimary,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        side: BorderSide(color: DesignColors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.left, this.right);
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            left,
            style: DesignTypography.bodyMedium.copyWith(
              color: DesignColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          right,
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
