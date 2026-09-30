import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/telemetry/telemetry_safe.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/analytics/analytics_blocks.dart';
import '../widgets/analytics/analytics_tab_switcher.dart';
import '../widgets/analytics/overview_sections.dart';

/// Analytics "Overview": everything an admin needs to run and grow the society,
/// in plain words — what needs attention, this week, money, gate & security,
/// service, people & app, growth and who to contact. Technical app metrics are
/// folded away at the bottom.
class AdminAppAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAppAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAppAnalyticsScreen> createState() => _AdminAppAnalyticsScreenState();
}

class _AdminAppAnalyticsScreenState extends ConsumerState<AdminAppAnalyticsScreen> {
  int _days = 30;

  /// Analytics tabs are swapped in place; other admin screens open on top.
  static const _tabRoutes = {
    'gate': '/resident/admin-gate-analytics',
    'complaints': '/resident/admin-complaint-analytics',
    'water': '/resident/admin-water-analytics',
  };
  static const _screenRoutes = {
    'dues': '/resident/admin-outstanding-dues',
    'sos': '/resident/admin-sos',
    'security': '/resident/admin-patrols',
  };

  Future<void> _refresh() async {
    // Recompute on the server first, then reload (the server caches for a minute).
    try {
      await ref.read(adminAppAnalyticsRepositoryProvider).getSocietyOverview(days: _days, fresh: true);
    } catch (_) {}
    ref.invalidate(adminSocietyOverviewProvider(_days));
    ref.invalidate(adminAppAnalyticsFlowsProvider);
    ref.invalidate(adminAppAnalyticsScreensProvider);
  }

  void _openRoute(String route) {
    if (_tabRoutes.containsValue(route)) {
      context.pushReplacement(route);
    } else {
      context.push(route);
    }
  }

  void _openArea(String? area) {
    final route = _tabRoutes[area] ?? _screenRoutes[area];
    if (route != null) _openRoute(route);
  }

  static const _listTitles = {
    'duesPending': 'Flats with pending dues',
    'neverOpened': 'Never opened the app',
    'cantGetAlerts': "Can't get alerts",
    'flatsWithoutApp': 'Flats not using the app',
    'regularVisitors': 'Regular visitors',
  };

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
                  for (final h in const [70.0, 110.0, 150.0, 110.0])
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
    final outreach = telemetrySafeMap(o['outreach']);
    final summary = (o['summary'] as List? ?? const []).map((e) => '$e').toList();
    final features = telemetrySafeMapList(o['features']);

    Widget section(String title, {String? subtitle, required Widget child}) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [AnalyticsSectionTitle(title, subtitle: subtitle), child],
          ),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AnalyticsSectionTitle(
          'Needs attention',
          subtitle: 'Most important first — tap to act',
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
                action: _attentionAction(a, outreach),
              ),
          ],
        ),
        if (summary.isNotEmpty)
          section('This week', subtitle: 'Compared with last week', child: OverviewWeekSummary(lines: summary)),
        section(
          'Money',
          subtitle: 'Collection, dues, income and spending',
          child: OverviewMoney(money: telemetrySafeMap(o['money']), days: _days, onOpen: _openRoute),
        ),
        section(
          'Gate & security',
          subtitle: 'Last $_days days',
          child: OverviewGateSecurity(
            gate: telemetrySafeMap(o['gate']),
            security: telemetrySafeMap(o['security']),
            onOpen: _openRoute,
          ),
        ),
        section(
          'Service',
          subtitle: 'Complaints, amenities, notices and water',
          child: OverviewService(service: telemetrySafeMap(o['service']), water: telemetrySafeMap(o['water'])),
        ),
        section(
          'People & app',
          subtitle: 'Who uses the app, phones and app health',
          child: OverviewPeopleApp(
            people: telemetrySafeMap(o['people']),
            app: telemetrySafeMap(o['app']),
            outreach: outreach,
            days: _days,
          ),
        ),
        section(
          'Growth',
          subtitle: 'Flats using the app each week (last 8 weeks)',
          child: OverviewGrowth(growth: telemetrySafeMap(o['growth'])),
        ),
        if (features.isNotEmpty)
          section(
            'Features residents use',
            subtitle: 'Higher is better — each one saves the guard or the office work',
            child: Column(
              children: [
                for (final f in features)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: _FeatureCard(feature: f)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const _TechnicalDetails(),
      ],
    );
  }

  /// Opens the contact list for the item, or the screen that explains it.
  Widget? _attentionAction(Map<String, dynamic> a, Map<String, dynamic> outreach) {
    final list = a['list']?.toString();
    final contacts = list == null ? const <Map<String, dynamic>>[] : telemetrySafeMapList(outreach[list]);
    if (contacts.isNotEmpty) {
      return IconButton(
        tooltip: 'See who',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.people_alt_outlined, color: DesignColors.primary),
        onPressed: () => showOverviewContacts(context, title: _listTitles[list] ?? 'People', contacts: contacts),
      );
    }
    final area = a['area']?.toString();
    if (_tabRoutes.containsKey(area) || _screenRoutes.containsKey(area)) {
      return IconButton(
        tooltip: 'Open',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.chevron_right_rounded, color: DesignColors.textSecondary),
        onPressed: () => _openArea(area),
      );
    }
    return null;
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

/// Folded by default: guard-task success and most-used screens.
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
            'Guard tasks and most-used screens',
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

  /// "/resident/community/notices" → "Community notices"; "/" → "App start".
  static String _shortScreen(String path) {
    const named = {'/': 'App start', '/resident': 'Resident home', '/guard': 'Guard home', 'home': 'Home'};
    if (named.containsKey(path)) return named[path]!;
    var p = path;
    for (final prefix in ['/resident/tab/', '/guard/tab/', '/resident/', '/guard/', '/']) {
      if (p.startsWith(prefix)) {
        p = p.substring(prefix.length);
        break;
      }
    }
    final words = p.replaceAll(RegExp(r'[/_-]+'), ' ').trim();
    if (words.isEmpty) return path;
    return words[0].toUpperCase() + words.substring(1);
  }
}
