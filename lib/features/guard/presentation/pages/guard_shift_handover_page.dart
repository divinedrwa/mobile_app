import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../resident/data/models/parcel_model.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_offline_sync_notifier.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_section_card.dart';

/// End-of-shift summary for the next guard: who is still inside, requests still
/// waiting, parcels at the gate and today's totals — shareable as text.
class GuardShiftHandoverPage extends ConsumerWidget {
  const GuardShiftHandoverPage({super.key});

  static final _time = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitorsAsync = ref.watch(guardActiveVisitorsTabProvider);
    final parcelsAsync = ref.watch(guardPendingParcelsProvider);
    final dashAsync = ref.watch(guardDashboardProvider);
    final pendingSync = ref.watch(offlineSyncProvider).pendingCount;

    final visitors = visitorsAsync.valueOrNull?.pendingVisitors ?? const <GuardVisitorRow>[];
    final inside = visitors
        .where((v) => v.awaitingCheckout && v.status.trim().toUpperCase() == 'CHECKED_IN')
        .toList();
    final waiting = visitors.where((v) => v.needsResidentApproval).toList();
    final parcels = (parcelsAsync.valueOrNull ?? const <ParcelModel>[])
        .where((p) => p.status == ParcelStatus.pending)
        .toList();
    final dash = dashAsync.valueOrNull;
    final stats = dash?.todayStats;
    final loading = visitorsAsync.isLoading || parcelsAsync.isLoading || dashAsync.isLoading;

    Future<void> refresh() async {
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPendingParcelsProvider);
      ref.invalidate(guardDashboardProvider);
      await ref.read(guardActiveVisitorsTabProvider.future);
    }

    String shareText() {
      final now = DateTime.now();
      final b = StringBuffer()
        ..writeln('Shift handover · ${dash?.gateName ?? 'Gate'}')
        ..writeln(DateFormat('d MMM y, h:mm a').format(now))
        ..writeln()
        ..writeln('Inside now: ${inside.length}');
      for (final v in inside) {
        b.writeln('• ${v.name}${v.villaLabel != null ? ' → ${v.villaLabel}' : ''}'
            ' (in ${_fmt(v.checkInTime)})');
      }
      b.writeln('Waiting on residents: ${waiting.length}');
      for (final v in waiting) {
        b.writeln('• ${v.name}${v.villaLabel != null ? ' → ${v.villaLabel}' : ''}'
            ' (since ${_fmt(v.checkInTime)})');
      }
      b.writeln('Parcels at gate: ${parcels.length}');
      for (final p in parcels) {
        b.writeln('• ${p.courier} (${_fmt(p.receivedAt)})');
      }
      if (stats != null) {
        b
          ..writeln()
          ..writeln('Today: ${stats.visitors} visitors · ${stats.parcels} deliveries · '
              '${stats.patrols} patrols · ${stats.incidents} incidents');
      }
      if (pendingSync > 0) {
        b.writeln('⚠ $pendingSync entries saved offline, not synced yet');
      }
      return b.toString().trim();
    }

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text('Shift handover', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              GuardTokens.padScreen,
              GuardTokens.g2,
              GuardTokens.padScreen,
              GuardTokens.sectionGap + 80,
            ),
            children: [
              Text(
                '${dash?.gateName ?? 'Your gate'} · ${DateFormat('EEE d MMM, h:mm a').format(DateTime.now())}',
                style: GuardTokens.captionStyle(context).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: GuardTokens.g2),
              if (loading && visitors.isEmpty)
                const LinearProgressIndicator(minHeight: 2),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  _StatTile(label: 'Inside now', value: inside.length, tone: GuardTokens.success, icon: Icons.meeting_room_rounded),
                  _StatTile(label: 'Waiting', value: waiting.length, tone: GuardTokens.warning, icon: Icons.hourglass_top_rounded),
                  _StatTile(label: 'Parcels at gate', value: parcels.length, tone: GuardTokens.guardAccentDeep, icon: Icons.inventory_2_rounded),
                  _StatTile(label: 'Visitors today', value: stats?.visitors, tone: GuardTokens.guardAccentDeep, icon: Icons.groups_rounded),
                  _StatTile(label: 'Patrols', value: stats?.patrols, tone: GuardTokens.guardAccentDeep, icon: Icons.directions_walk_rounded),
                  _StatTile(label: 'Incidents', value: stats?.incidents, tone: GuardTokens.dangerBrand, icon: Icons.report_rounded),
                ],
              ),
              if (pendingSync > 0) ...[
                const SizedBox(height: GuardTokens.g2),
                _Notice(
                  icon: Icons.cloud_off_rounded,
                  text: '$pendingSync ${pendingSync == 1 ? 'entry' : 'entries'} saved offline, not synced yet. '
                      'Keep this phone online until they sync.',
                ),
              ],
              const SizedBox(height: GuardTokens.sectionGap),
              _ListSection(
                icon: Icons.meeting_room_rounded,
                title: 'Still inside',
                emptyText: 'Nobody inside — all exits marked.',
                rows: [
                  for (final v in inside)
                    (v.name, [if (v.villaLabel != null) 'Flat ${v.villaLabel}', 'in ${_fmt(v.checkInTime)}'].join(' · ')),
                ],
              ),
              const SizedBox(height: GuardTokens.sectionGap),
              _ListSection(
                icon: Icons.hourglass_top_rounded,
                title: 'Waiting on residents',
                emptyText: 'No pending requests.',
                rows: [
                  for (final v in waiting)
                    (v.name, [if (v.villaLabel != null) 'Flat ${v.villaLabel}', 'since ${_fmt(v.checkInTime)}'].join(' · ')),
                ],
              ),
              const SizedBox(height: GuardTokens.sectionGap),
              _ListSection(
                icon: Icons.inventory_2_rounded,
                title: 'Parcels waiting at gate',
                emptyText: 'No parcels waiting.',
                rows: [
                  for (final p in parcels) (p.courier, 'received ${_fmt(p.receivedAt)}'),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(GuardTokens.padScreen, 8, GuardTokens.padScreen, 12),
            child: FilledButton.icon(
              style: GuardTokens.primaryFilled(context).copyWith(
                minimumSize: WidgetStateProperty.all(const Size.fromHeight(GuardTokens.btnPrimaryH + 4)),
              ),
              onPressed: loading && visitors.isEmpty ? null : () => Share.share(shareText(), subject: 'Shift handover'),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text(
                'Share handover',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime? t) {
    if (t == null) return '--';
    final l = t.toLocal();
    final now = DateTime.now();
    final sameDay = l.year == now.year && l.month == now.month && l.day == now.day;
    return sameDay ? _time.format(l) : DateFormat('d MMM, h:mm a').format(l);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.tone, required this.icon});

  final String label;
  final int? value;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: tone),
          Text(
            value?.toString() ?? '–',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: tone, height: 1),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GuardTokens.captionStyle(context).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GuardTokens.warningMuted,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(color: GuardTokens.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GuardTokens.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GuardTokens.bodyStyle(context).copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return GuardSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuardScreenSectionHeader(icon: icon, title: '$title (${rows.length})'),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(emptyText, style: GuardTokens.captionStyle(context)),
            )
          else
            for (final (name, meta) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GuardTokens.guardAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GuardTokens.bodyStyle(context).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(meta, style: GuardTokens.captionStyle(context)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
