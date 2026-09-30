import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/telemetry/telemetry_safe.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/analytics/analytics_bar_chart.dart';
import '../widgets/analytics/analytics_blocks.dart';
import '../widgets/analytics/analytics_tab_switcher.dart';

/// Analytics "Overview": how the society is doing, in plain words — what needs
/// attention, one card per area (tap to open its tab), who uses the app and
/// which self-service features residents use. Technical app metrics are folded
/// away at the bottom.
class AdminAppAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAppAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAppAnalyticsScreen> createState() => _AdminAppAnalyticsScreenState();
}

class _AdminAppAnalyticsScreenState extends ConsumerState<AdminAppAnalyticsScreen> {
  int _days = 30;

  static const _areaRoutes = {
    'gate': '/resident/admin-gate-analytics',
    'complaints': '/resident/admin-complaint-analytics',
    'water': '/resident/admin-water-analytics',
    'dues': '/resident/admin-reconciliation',
    'sos': '/resident/admin-sos',
  };

  static const _areaIcons = {
    'gate': Icons.how_to_reg_rounded,
    'complaints': Icons.report_problem_rounded,
    'dues': Icons.account_balance_wallet_rounded,
    'water': Icons.water_drop_rounded,
    'app': Icons.smartphone_rounded,
  };

  Future<void> _refresh() async {
    ref.invalidate(adminSocietyOverviewProvider(_days));
    ref.invalidate(adminAppAnalyticsFlowsProvider);
    ref.invalidate(adminAppAnalyticsScreensProvider);
    ref.invalidate(adminAppAnalyticsInsightsProvider);
  }

  void _open(String? area) {
    final route = _areaRoutes[area];
    if (route == null) return;
    if (area == 'sos') {
      context.push(route);
    } else {
      context.pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminSocietyOverviewProvider(_days));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Analytics',
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: AnalyticsTabSwitcher(currentRoute: '/resident/admin-app-analytics'),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: overviewAsync.when(
          skipLoadingOnReload: true,
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: [
                  for (final h in const [70.0, 110.0, 110.0, 110.0])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ShimmerBox(height: h, borderRadius: DesignRadius.lg),
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
                  title: 'Could not load the overview',
                  subtitle: 'Check the connection and try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: _body,
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> o) {
    final attention = telemetrySafeMapList(o['attention']);
    final areas = telemetrySafeMapList(o['areas']);
    final people = telemetrySafeMap(o['people']);
    final roles = telemetrySafeMapList(people['roles']);
    final features = telemetrySafeMapList(o['features']);
    final daily = telemetrySafeMapList(o['dailyActive']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AnalyticsSectionTitle(
          'Needs attention',
          subtitle: 'What to act on first',
          trailing: _PeriodChips(value: _days, onChanged: (d) => setState(() => _days = d)),
        ),
        AnalyticsAttentionList(
          emptyText: 'All clear — nothing needs your attention right now.',
          items: [
            for (final a in attention)
              AnalyticsAttentionItem(
                title: a['title']?.toString() ?? '',
                detail: a['detail']?.toString(),
                tone: switch (a['severity']) {
                  'critical' => 'critical',
                  'warning' => 'watch',
                  _ => 'neutral',
                },
                action: _areaRoutes.containsKey(a['area'])
                    ? IconButton(
                        tooltip: 'Open',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.chevron_right_rounded, color: DesignColors.textSecondary),
                        onPressed: () => _open(a['area']?.toString()),
                      )
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
        AnalyticsSectionTitle(
          'Last $_days days',
          subtitle: 'Tap a card for the full details',
        ),
        for (final a in areas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AreaCard(
              area: a,
              icon: _areaIcons[a['id']] ?? Icons.insights_rounded,
              onTap: _areaRoutes.containsKey(a['id']) ? () => _open(a['id']?.toString()) : null,
            ),
          ),
        const SizedBox(height: 10),
        AnalyticsSectionTitle(
          'Who uses the app',
          subtitle:
              '${analyticsInt(people['using'])} of ${analyticsInt(people['total'])} people opened it in the last $_days days',
        ),
        _PeopleCard(roles: roles),
        const SizedBox(height: 20),
        if (features.isNotEmpty) ...[
          const AnalyticsSectionTitle(
            'Features residents use',
            subtitle: 'Higher is better — each one saves the guard or the office work',
          ),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FeatureCard(feature: f),
            ),
          const SizedBox(height: 10),
        ],
        const AnalyticsSectionTitle(
          'People using the app each day',
          subtitle: 'Residents, guards and admins who opened it',
        ),
        AnalyticsBarChart(
          height: 160,
          color: DesignColors.primary,
          emptyTitle: 'No app activity yet',
          emptySubtitle: 'This fills in as people open the app.',
          points: [
            for (final d in daily)
              AnalyticsBarPoint(
                label: d['label']?.toString() ?? '',
                value: analyticsDouble(d['count']),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const _TechnicalDetails(),
      ],
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final d in const [7, 30, 90])
          ChoiceChip(
            label: Text('${d}d'),
            selected: value == d,
            onSelected: (_) => onChanged(d),
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: value == d ? Colors.white : DesignColors.textSecondary,
            ),
            selectedColor: DesignColors.primary,
            showCheckmark: false,
          ),
      ],
    );
  }
}

/// Icon, big number with its meaning, one line of context and the change vs before.
class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.icon, this.onTap});

  final Map<String, dynamic> area;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = area['tone']?.toString() ?? 'neutral';
    final toneColor = tone == 'neutral' ? DesignColors.primary : analyticsToneColor(tone);
    final change = telemetrySafeMap(area['change']);
    final hasChange = change['label'] != null;
    final changeColor = change['direction'] == 'flat'
        ? DesignColors.textSecondary
        : (change['good'] == true ? DesignColors.success : DesignColors.error);

    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: toneColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: toneColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area['title']?.toString() ?? '',
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: area['value']?.toString() ?? '—',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: tone == 'neutral' ? DesignColors.textPrimary : toneColor,
                            ),
                          ),
                          TextSpan(
                            text: '  ${area['label'] ?? ''}',
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      area['detail']?.toString() ?? '',
                      style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
                    ),
                    if (hasChange) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            switch (change['direction']) {
                              'up' => Icons.arrow_upward_rounded,
                              'down' => Icons.arrow_downward_rounded,
                              _ => Icons.remove_rounded,
                            },
                            size: 14,
                            color: changeColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            change['label'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: changeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: DesignColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bar per role: green = using, amber = stopped, grey = never opened.
class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.roles});

  final List<Map<String, dynamic>> roles;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return AnalyticsCard(
        child: Text(
          'No accounts yet.',
          style: DesignTypography.bodySmall.copyWith(color: DesignColors.textTertiary),
        ),
      );
    }
    return AnalyticsCard(
      child: Column(
        children: [
          for (var i = 0; i < roles.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _roleRow(roles[i]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _legend(DesignColors.success, 'Using'),
              _legend(DesignColors.warning, 'Stopped using'),
              _legend(DesignColors.borderLight, 'Never opened'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleRow(Map<String, dynamic> r) {
    final total = analyticsInt(r['total']);
    final using = analyticsInt(r['using']);
    final stopped = analyticsInt(r['stopped']);
    final never = analyticsInt(r['never']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                r['label']?.toString() ?? '',
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$using of $total using',
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (using > 0) Expanded(flex: using, child: ColoredBox(color: DesignColors.success)),
                if (stopped > 0) Expanded(flex: stopped, child: ColoredBox(color: DesignColors.warning)),
                if (never > 0) Expanded(flex: never, child: ColoredBox(color: DesignColors.borderLight)),
                if (total == 0) Expanded(child: ColoredBox(color: DesignColors.borderLight)),
              ],
            ),
          ),
        ),
        if (stopped + never > 0) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (stopped > 0) '$stopped stopped using it',
              if (never > 0) '$never never opened it',
            ].join(' · '),
            style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _legend(Color c, String label) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(label, style: DesignTypography.captionSmall.copyWith(fontSize: 11)),
          ],
        ),
      );
}

/// "Invite guests in advance — 1 of 25 flats (4%)" with a progress bar and a tip.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final Map<String, dynamic> feature;

  @override
  Widget build(BuildContext context) {
    final pct = analyticsInt(feature['pct']);
    final color = analyticsToneColor(feature['tone']?.toString() ?? 'neutral');
    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  feature['label']?.toString() ?? '',
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ),
              AnalyticsPill('$pct%', tone: feature['tone']?.toString() ?? 'neutral'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${analyticsInt(feature['used'])} of ${analyticsInt(feature['of'])} ${feature['unit'] ?? ''}',
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: DesignColors.borderLight,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 15, color: DesignColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feature['tip']?.toString() ?? '',
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Folded by default: guard-flow success, most-used screens and return rates.
class _TechnicalDetails extends ConsumerWidget {
  const _TechnicalDetails();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnalyticsCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(Icons.tune_rounded, color: DesignColors.textSecondary),
          title: Text(
            'Technical details',
            style: DesignTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Guard tasks, most-used screens, return rates',
            style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
          ),
          children: [_TechnicalBody()],
        ),
      ),
    );
  }
}

class _TechnicalBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flows = ref.watch(adminAppAnalyticsFlowsProvider).valueOrNull ?? const [];
    final screens = ref.watch(adminAppAnalyticsScreensProvider).valueOrNull ?? const [];
    final insights = ref.watch(adminAppAnalyticsInsightsProvider).valueOrNull ?? const {};
    final retention = telemetrySafeMap(insights['retention']);
    final peak = telemetrySafeMapList(insights['peakHours']);

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesignTypography.captionSmall.copyWith(color: DesignColors.textPrimary),
                ),
              ),
              Text(
                value,
                style: DesignTypography.captionSmall.copyWith(
                  color: DesignColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(
            t,
            style: DesignTypography.captionSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: DesignColors.textSecondary,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Came back to the app'),
        line('Next day', '${retention['d1Pct'] ?? 0}%'),
        line('Within a week', '${retention['d7Pct'] ?? 0}%'),
        line('Within a month', '${retention['d30Pct'] ?? 0}%'),
        if (peak.isNotEmpty) line('Busiest hour', peak.first['label']?.toString() ?? '—'),
        heading('Guard tasks'),
        if (flows.isEmpty) line('No guard task data yet', ''),
        for (final f in flows.take(6))
          line(
            f['label']?.toString() ?? (f['flowId']?.toString() ?? '').replaceAll('_', ' '),
            '${analyticsInt(f['count'])} · ${f['successRate'] ?? 0}% ok',
          ),
        heading('Most-used screens'),
        if (screens.isEmpty) line('No screen data yet', ''),
        for (final s in screens.take(6))
          line(_shortScreen(s['screen']?.toString() ?? ''), '${analyticsInt(s['views'])} views'),
      ],
    );
  }

  static String _shortScreen(String path) {
    for (final prefix in ['/resident/tab/', '/guard/tab/', '/resident/', '/guard/']) {
      if (path.startsWith(prefix)) return path.substring(prefix.length);
    }
    return path;
  }
}
