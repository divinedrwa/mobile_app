import 'package:flutter/material.dart';

import '../../../../../core/telemetry/telemetry_safe.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/utils/phone_launch.dart';
import 'analytics_bar_chart.dart';
import 'analytics_blocks.dart';

/// Building blocks and sections for the Analytics "Overview" tab. Every section
/// reads one part of the `/app-analytics/society-overview` payload.

typedef _J = Map<String, dynamic>;

_J _m(dynamic v) => telemetrySafeMap(v);
List<_J> _l(dynamic v) => telemetrySafeMapList(v);
String _s(dynamic v, [String fallback = '—']) => (v == null || '$v'.isEmpty) ? fallback : '$v';
String _plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

// ── Small shared widgets ─────────────────────────────────────────────

/// One number with what it means, e.g. "7 · people let in".
class OverviewStat {
  const OverviewStat(this.value, this.label, {this.tone = 'neutral', this.hint});

  final String value;
  final String label;
  final String tone;
  final String? hint;
}

/// Two-column grid of numbers that never truncates the labels.
class OverviewStatGrid extends StatelessWidget {
  const OverviewStatGrid({super.key, required this.stats});

  final List<OverviewStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in stats)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                    border: Border.all(color: DesignColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: s.tone == 'neutral' ? DesignColors.textPrimary : analyticsToneColor(s.tone),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.label,
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (s.hint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.hint!,
                          style: DesignTypography.captionSmall.copyWith(
                            color: DesignColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Label ........ value" rows inside a card.
class OverviewRows extends StatelessWidget {
  const OverviewRows({super.key, required this.rows, this.title});

  final String? title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: DesignTypography.bodySmall.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
          ],
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: DesignTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DesignColors.textPrimary,
                      ),
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

/// Change vs the previous period: "↑ +40% vs before" in green/red.
class OverviewChange extends StatelessWidget {
  const OverviewChange(this.change, {super.key});

  final _J change;

  @override
  Widget build(BuildContext context) {
    if (change['label'] == null) return const SizedBox.shrink();
    final dir = change['direction'];
    final color = dir == 'flat'
        ? DesignColors.textSecondary
        : (change['good'] == true ? DesignColors.success : DesignColors.error);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          dir == 'up'
              ? Icons.arrow_upward_rounded
              : dir == 'down'
                  ? Icons.arrow_downward_rounded
                  : Icons.remove_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '${change['label']}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

/// A tappable "See who (7)" row that opens the contact list.
class OverviewListButton extends StatelessWidget {
  const OverviewListButton({super.key, required this.label, required this.contacts, required this.title});

  final String label;
  final String title;
  final List<_J> contacts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(DesignRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.md),
        onTap: contacts.isEmpty ? null : () => showOverviewContacts(context, title: title, contacts: contacts),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.people_alt_rounded, size: 18, color: DesignColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.primary,
                  ),
                ),
              ),
              Text(
                '${contacts.length}',
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DesignColors.primary,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: DesignColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing people to contact, each with a Call button.
Future<void> showOverviewContacts(
  BuildContext context, {
  required String title,
  required List<_J> contacts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '$title (${contacts.length})',
              style: DesignTypography.headingM.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: contacts.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: DesignColors.borderLight),
              itemBuilder: (ctx, i) {
                final c = contacts[i];
                final phone = c['phone']?.toString();
                final meta = [
                  if (c['flat'] != null) 'Flat ${c['flat']}',
                  if (c['amount'] != null) '${c['amount']}',
                  if (c['detail'] != null) '${c['detail']}',
                ].join(' · ');
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    _s(c['name'], 'Resident'),
                    style: DesignTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [meta, if (phone != null && phone.isNotEmpty) phone].where((s) => s.isNotEmpty).join('\n'),
                    style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
                  ),
                  isThreeLine: phone != null && phone.isNotEmpty && meta.isNotEmpty,
                  trailing: phone == null || phone.isEmpty
                      ? null
                      : IconButton.filledTonal(
                          tooltip: 'Call',
                          icon: const Icon(Icons.call_rounded),
                          onPressed: () async {
                            final ok = await launchDial(phone);
                            if (!ok && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Cannot dial $phone')),
                              );
                            }
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

List<AnalyticsShare> _shares(List<_J> rows, List<Color> palette, {String valueKey = 'value', String? metaKey}) {
  return [
    for (var i = 0; i < rows.length; i++)
      AnalyticsShare(
        _s(rows[i]['label']),
        analyticsInt(rows[i][valueKey]),
        palette[i % palette.length],
        meta: metaKey == null ? null : _s(rows[i][metaKey]),
        // Money rows carry a formatted amount ("₹23,800").
        valueLabel: rows[i]['amount']?.toString(),
      ),
  ];
}

const _palette = [
  Color(0xFF1D4ED8),
  Color(0xFF0E7490),
  Color(0xFF7C3AED),
  Color(0xFFEA580C),
  Color(0xFF16A34A),
];

// ── This week ────────────────────────────────────────────────────────

class OverviewWeekSummary extends StatelessWidget {
  const OverviewWeekSummary({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: DesignColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line,
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textPrimary,
                        height: 1.4,
                      ),
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

// ── Money ────────────────────────────────────────────────────────────

class OverviewMoney extends StatelessWidget {
  const OverviewMoney({super.key, required this.money, required this.days, required this.onOpen});

  final _J money;
  final int days;
  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final pending = _m(money['pending']);
    final received = _m(money['received']);
    final expenses = _m(money['expenses']);
    final online = _m(money['onlinePayments']);
    final rate = analyticsDouble(money['collectionRatePct']);
    final tone = _s(money['collectionTone'], 'neutral');
    final cover = money['monthsOfCover'];
    final net = analyticsDouble(money['netValue']);
    final failed = analyticsInt(online['failed']) + analyticsInt(online['abandoned']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: analyticsToneColor(tone)),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'of all maintenance collected',
                      style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (rate / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: DesignColors.borderLight,
                  color: analyticsToneColor(tone),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_s(money['collected'])} of ${_s(money['expected'])} billed so far',
                style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Society fund', style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary)),
                        Text(
                          _s(money['fundBalance']),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  if (cover != null)
                    AnalyticsPill(
                      'Covers ${_coverLabel(analyticsDouble(cover))}',
                      tone: analyticsDouble(cover) < 1 ? 'critical' : (analyticsDouble(cover) < 3 ? 'watch' : 'good'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OverviewStatGrid(stats: [
          OverviewStat(_s(received['amount']), 'received in $days days',
              hint: '${_plural(analyticsInt(received['flats']), 'flat')} paid · ${analyticsInt(received['onlinePct'])}% online'),
          OverviewStat(_s(expenses['amount']), 'spent in $days days', hint: _s(_m(expenses['change'])['label'], '')),
          OverviewStat(_s(money['net']), net >= 0 ? 'saved (in − out)' : 'more spent than received',
              tone: net >= 0 ? 'good' : 'critical'),
          OverviewStat(_s(pending['amount']), 'pending dues',
              tone: analyticsInt(pending['flats']) > 0 ? 'watch' : 'good',
              hint: '${_plural(analyticsInt(pending['flats']), 'flat')} · ${analyticsInt(pending['chronicFlats'])} for 2+ months'),
        ]),
        const SizedBox(height: 10),
        OverviewListButton(
          label: 'Who owes — call or remind',
          title: 'Flats with pending dues',
          contacts: _l(pending['top']),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onOpen('/resident/admin-reminders'),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Send reminder'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onOpen('/resident/admin-outstanding-dues'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Dues screen'),
              ),
            ),
          ],
        ),
        if (failed > 0) ...[
          const SizedBox(height: 10),
          AnalyticsAttentionList(
            emptyText: '',
            items: [
              AnalyticsAttentionItem(
                title: '${_plural(failed, 'online payment')} didn\'t go through',
                detail: '${analyticsInt(online['failed'])} failed at the bank, '
                    '${analyticsInt(online['abandoned'])} started but not finished.',
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const AnalyticsSectionTitle('How residents paid'),
        AnalyticsShareBars(
          items: _shares(_l(received['byMode']), _palette),
          emptyText: 'No payments in this period.',
        ),
        const SizedBox(height: 14),
        AnalyticsSectionTitle(
          'Where the money went',
          subtitle: 'Top expense heads',
          trailing: TextButton(
            onPressed: () => onOpen('/resident/admin-expenses'),
            child: const Text('Expenses'),
          ),
        ),
        AnalyticsShareBars(
          items: _shares(_l(expenses['top']), _palette),
          emptyText: 'No expenses recorded in this period.',
        ),
      ],
    );
  }

  static String _coverLabel(double months) {
    if (months < 1) {
      final days = (months * 30).round();
      return days <= 1 ? 'about a day' : 'about $days days';
    }
    return months < 1.5 ? 'about a month' : '${months.toStringAsFixed(1)} months';
  }
}

// ── Gate & security ──────────────────────────────────────────────────

class OverviewGateSecurity extends StatelessWidget {
  const OverviewGateSecurity({super.key, required this.gate, required this.security, required this.onOpen});

  final _J gate;
  final _J security;
  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final deliveries = _m(gate['deliveries']);
    final patrols = _m(security['patrols']);
    final sos = _m(security['sos']);
    final staff = _m(security['staff']);
    final regular = _l(gate['regularVisitors']);
    final waitingParcels = analyticsInt(deliveries['waitingOverADay']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OverviewStatGrid(stats: [
          OverviewStat('${analyticsInt(gate['letIn'])}', 'people let in',
              hint: '${_plural(analyticsInt(gate['requests']), 'gate request')}'),
          OverviewStat('${analyticsInt(gate['answeredInAppPct'])}%', 'answered in the app',
              tone: analyticsTone(analyticsInt(gate['answeredInAppPct']), 75, 50),
              hint: gate['typicalReply'] == null ? null : 'Typical reply ${gate['typicalReply']}'),
          OverviewStat('${analyticsInt(gate['insideNow'])}', 'inside right now'),
          OverviewStat('${analyticsInt(gate['waitingNow'])}', 'waiting for a reply',
              tone: analyticsInt(gate['waitingNow']) > 0 ? 'watch' : 'good'),
        ]),
        const SizedBox(height: 10),
        OverviewRows(rows: [
          ('Busiest time at the gate', _s(gate['busiestHour'])),
          ('Busiest day', _s(gate['busiestDay'])),
          ('Deliveries received', '${analyticsInt(deliveries['received'])} (${analyticsInt(deliveries['handedOver'])} handed over)'),
          ('Parcels at gate over a day', '$waitingParcels'),
          ('Vehicle entries logged', '${analyticsInt(gate['vehicleEntries'])}'),
        ]),
        if (regular.isNotEmpty) ...[
          const SizedBox(height: 10),
          OverviewListButton(
            label: 'Regular visitors — give a standing pass',
            title: 'Regular visitors',
            contacts: regular,
          ),
        ],
        const SizedBox(height: 10),
        OverviewRows(
          title: 'Security',
          rows: [
            (
              'Patrol rounds done',
              analyticsInt(patrols['planned']) == 0
                  ? 'None planned'
                  : '${analyticsInt(patrols['done'])} of ${analyticsInt(patrols['planned'])}'
                      '${analyticsInt(patrols['missed']) > 0 ? ' · ${analyticsInt(patrols['missed'])} missed' : ''}',
            ),
            ('SOS alerts', analyticsInt(sos['total']) == 0 ? 'None' : '${analyticsInt(sos['total'])} (${analyticsInt(sos['open'])} open)'),
            if (sos['typicalAck'] != null) ('Typical time to respond', _s(sos['typicalAck'])),
            if (sos['typicalResolve'] != null) ('Typical time to resolve', _s(sos['typicalResolve'])),
            (
              'Staff present today',
              analyticsInt(staff['onRoll']) == 0
                  ? 'No staff added'
                  : '${analyticsInt(staff['presentToday'])} of ${analyticsInt(staff['onRoll'])}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 16),
              label: const Text('Parcels'),
              onPressed: () => onOpen('/resident/admin-parcels'),
            ),
            ActionChip(
              avatar: const Icon(Icons.directions_walk_rounded, size: 16),
              label: const Text('Patrols'),
              onPressed: () => onOpen('/resident/admin-patrols'),
            ),
            ActionChip(
              avatar: const Icon(Icons.sos_rounded, size: 16),
              label: const Text('SOS'),
              onPressed: () => onOpen('/resident/admin-sos'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Service ──────────────────────────────────────────────────────────

class OverviewService extends StatelessWidget {
  const OverviewService({super.key, required this.service, required this.water});

  final _J service;
  final _J water;

  @override
  Widget build(BuildContext context) {
    final c = _m(service['complaints']);
    final a = _m(service['amenities']);
    final alerts = _m(service['alerts']);
    final contracts = _l(service['contractsEnding']);
    final projects = _l(service['projects']);
    final topCats = _l(c['topCategories']);
    final topAmenities = _l(a['top']);
    final unused = (a['unused'] as List? ?? const []).map((e) => '$e').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OverviewStatGrid(stats: [
          OverviewStat('${analyticsInt(c['open'])}', 'complaints open',
              tone: analyticsInt(c['overdue']) > 0 ? 'critical' : (analyticsInt(c['open']) > 0 ? 'watch' : 'good'),
              hint: analyticsInt(c['overdue']) > 0 ? '${analyticsInt(c['overdue'])} over 7 days' : null),
          OverviewStat(
            c['typicalFixDays'] == null ? '—' : '${c['typicalFixDays']} days',
            'typical time to fix',
            hint: '${analyticsInt(c['resolved'])} fixed · ${analyticsInt(c['filed'])} filed',
          ),
          OverviewStat('${analyticsInt(alerts['openedPct'])}%', 'of alerts read',
              tone: analyticsTone(analyticsInt(alerts['openedPct']), 40, 15),
              hint: '${analyticsInt(alerts['opened'])} of ${analyticsInt(alerts['sent'])}'),
          OverviewStat(_s(water['perDay']), 'water per day', tone: _s(water['tone'], 'neutral'), hint: _s(water['detail'], '')),
        ]),
        const SizedBox(height: 10),
        OverviewRows(rows: [
          if (topCats.isNotEmpty)
            ('Most complaints about', topCats.map((e) => '${e['label']} (${e['count']})').join(', ')),
          if (analyticsInt(c['repeatFlats']) > 0) ('Flats complaining again', '${analyticsInt(c['repeatFlats'])}'),
          ('Amenity bookings', '${analyticsInt(a['bookings'])}${analyticsInt(a['cancelled']) > 0 ? ' (${analyticsInt(a['cancelled'])} cancelled)' : ''}'),
          if (topAmenities.isNotEmpty)
            ('Most booked', topAmenities.map((e) => '${e['label']} (${e['count']})').join(', ')),
          if (unused.isNotEmpty) ('Not booked at all', unused.join(', ')),
          ('Notices published', '${analyticsInt(_m(service['notices'])['published'])}'),
          if (analyticsInt(alerts['notDelivered']) > 0) ('Alerts not delivered', '${analyticsInt(alerts['notDelivered'])}'),
        ]),
        if (contracts.isNotEmpty) ...[
          const SizedBox(height: 10),
          OverviewRows(
            title: 'Contracts ending soon',
            rows: [for (final k in contracts) ('${k['vendor']} — ${k['title']}', 'in ${_plural(analyticsInt(k['daysLeft']), 'day')}')],
          ),
        ],
        if (projects.isNotEmpty) ...[
          const SizedBox(height: 10),
          OverviewRows(
            title: 'Special projects',
            rows: [for (final pr in projects) ('${pr['title']}', '${pr['collected']} of ${pr['target']} (${pr['pct']}%)')],
          ),
        ],
      ],
    );
  }
}

// ── People & app ─────────────────────────────────────────────────────

class OverviewPeopleApp extends StatelessWidget {
  const OverviewPeopleApp({super.key, required this.people, required this.app, required this.outreach, required this.days});

  final _J people;
  final _J app;
  final _J outreach;
  final int days;

  @override
  Widget build(BuildContext context) {
    final roles = _l(people['roles']);
    final versions = _m(people['versions']);
    final newRes = _m(people['newResidents']);
    final devices = _m(app['devices']);
    final health = _m(app['health']);
    final cameBack = _m(app['cameBack']);
    final daily = _l(app['daily']);
    final since = _s(app['trackingSince'], '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OverviewStatGrid(stats: [
          OverviewStat('${analyticsInt(app['liveNow'])}', 'using the app now', tone: 'good'),
          OverviewStat('${analyticsInt(app['activeToday'])}', 'used it today',
              hint: '${analyticsInt(app['activeWeek'])} this week · ${analyticsInt(app['activeMonth'])} this month'),
          OverviewStat('${analyticsInt(people['flatsWithoutApp'])} of ${analyticsInt(people['occupiedFlats'])}',
              'flats not using the app',
              tone: analyticsInt(people['flatsWithoutApp']) > 0 ? 'watch' : 'good'),
          OverviewStat('${analyticsInt(people['cantGetAlerts'])}', "residents can't get alerts",
              tone: analyticsInt(people['cantGetAlerts']) > 0 ? 'watch' : 'good',
              hint: 'Signed out or removed the app'),
        ]),
        const SizedBox(height: 10),
        _RolesCard(roles: roles),
        const SizedBox(height: 10),
        OverviewRows(
          title: 'Installs & sign-ins in $days days',
          rows: [
            ('New phones (installs)', '${analyticsInt(app['installs'])}'),
            ('Uninstalls', since.isEmpty ? '${analyticsInt(app['uninstalls'])}' : '${analyticsInt(app['uninstalls'])} (since ${_dateLabel(since)})'),
            ('Password sign-ins', since.isEmpty ? '${analyticsInt(app['signIns'])}' : '${analyticsInt(app['signIns'])} (since ${_dateLabel(since)})'),
            ('Sign-outs', '${analyticsInt(app['signOuts'])}'),
            ('App opened', '${analyticsInt(app['appOpens'])} times'),
            ('New residents added', '${analyticsInt(newRes['added'])} (${analyticsInt(newRes['signedIn'])} signed in)'),
          ],
        ),
        const SizedBox(height: 10),
        OverviewRows(
          title: 'Phones',
          rows: [
            ('Phones getting alerts', '${analyticsInt(devices['active'])} for ${_plural(analyticsInt(devices['people']), 'person', 'people')}'),
            ('One phone / two / three or more', '${analyticsInt(devices['onePhone'])} / ${analyticsInt(devices['twoPhones'])} / ${analyticsInt(devices['threePlus'])}'),
            ('Android / iPhone', _l(devices['byPlatform']).map((e) => '${e['label']} ${e['pct']}%').join(' · ').ifEmpty('—')),
            if (_l(devices['topModels']).isNotEmpty)
              ('Common phones', _l(devices['topModels']).take(3).map((e) => '${e['label']}').join(', ')),
            ('Latest app version', _s(versions['latest'])),
            ('People on an older version', '${analyticsInt(versions['onOld'])}'),
          ],
        ),
        const SizedBox(height: 10),
        OverviewRows(
          title: 'App health',
          rows: [
            ('Visits without any problem', '${analyticsInt(health['problemFreePct'])}%'),
            ('Slow or dropped connection', '${analyticsInt(health['connectionProblems'])}'),
            ('App errors', '${analyticsInt(health['appErrors'])}'),
            for (final e in _l(health['topProblems']).take(3))
              ('• ${e['label']}', '${e['count']} (${_plural(analyticsInt(e['people']), 'person', 'people')})'),
            ('Busiest time in the app', '${_s(app['busiestHour'])} · ${_s(app['busiestDay'])}'),
            ('Came back next day / week / month',
                '${analyticsInt(cameBack['nextDay'])}% / ${analyticsInt(cameBack['week'])}% / ${analyticsInt(cameBack['month'])}%'),
          ],
        ),
        const SizedBox(height: 14),
        const AnalyticsSectionTitle('People using the app each day'),
        AnalyticsBarChart(
          height: 150,
          color: DesignColors.primary,
          emptyTitle: 'No app activity yet',
          points: [for (final d in daily) AnalyticsBarPoint(label: _s(d['label']), value: analyticsDouble(d['active']))],
        ),
        const SizedBox(height: 14),
        const AnalyticsSectionTitle('Who to contact', subtitle: 'Tap a list to call people'),
        OverviewListButton(
          label: 'Never opened the app',
          title: 'Never opened the app',
          contacts: _l(outreach['neverOpened']),
        ),
        const SizedBox(height: 8),
        OverviewListButton(
          label: "Can't get alerts on their phone",
          title: "Can't get alerts",
          contacts: _l(outreach['cantGetAlerts']),
        ),
        const SizedBox(height: 8),
        OverviewListButton(
          label: 'Flats not using the app',
          title: 'Flats not using the app',
          contacts: _l(outreach['flatsWithoutApp']),
        ),
      ],
    );
  }

  static String _dateLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// One bar per role: green = using, amber = stopped, grey = never opened.
class _RolesCard extends StatelessWidget {
  const _RolesCard({required this.roles});

  final List<_J> roles;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      child: Column(
        children: [
          for (var i = 0; i < roles.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _row(roles[i]),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
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

  Widget _row(_J r) {
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
                _s(r['label']),
                style: DesignTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
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
              // Stretch: a childless ColoredBox is otherwise zero pixels tall.
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: DesignTypography.captionSmall.copyWith(fontSize: 11)),
        ],
      );
}

// ── Growth ───────────────────────────────────────────────────────────

class OverviewGrowth extends StatelessWidget {
  const OverviewGrowth({super.key, required this.growth});

  final _J growth;

  @override
  Widget build(BuildContext context) {
    final weeks = _l(growth['weeklyActiveFlats']);
    final signal = _m(growth['signal']);
    final tone = _s(signal['tone'], 'neutral');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: analyticsToneColor(tone).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DesignRadius.md),
            border: Border.all(color: analyticsToneColor(tone).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                tone == 'good' ? Icons.trending_up_rounded : Icons.insights_rounded,
                color: analyticsToneColor(tone),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${analyticsInt(growth['thisWeek'])} of ${analyticsInt(growth['occupiedFlats'])} flats used the app this week',
                      style: DesignTypography.bodySmall.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _s(signal['text'], ''),
                      style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    OverviewChange(_m(growth['change'])),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnalyticsBarChart(
          height: 150,
          color: const Color(0xFF0E7490),
          emptyTitle: 'No weekly data yet',
          points: [for (final w in weeks) AnalyticsBarPoint(label: _s(w['label']), value: analyticsDouble(w['flats']))],
        ),
      ],
    );
  }
}
