import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_error_banner.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_skeletons.dart';

class GuardPatrolScreen extends ConsumerStatefulWidget {
  const GuardPatrolScreen({super.key});

  @override
  ConsumerState<GuardPatrolScreen> createState() => _GuardPatrolScreenState();
}

class _GuardPatrolScreenState extends ConsumerState<GuardPatrolScreen> {
  bool _busy = false;

  Future<void> _startPatrol() async {
    final location = await _promptLocation('Start patrol');
    if (location == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(guardRepositoryProvider).startPatrol(location: location);
      ref.invalidate(guardPatrolsTodayProvider);
      ref.invalidate(guardMyPatrolsProvider);
      ref.invalidate(guardDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Patrol started'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(userFacingMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logCheckpoint() async {
    final result = await _promptCheckpoint();
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(guardRepositoryProvider).logPatrolCheckpoint(
            location: result.location,
            notes: result.notes,
            issuesFound: result.issuesFound,
          );
      ref.invalidate(guardPatrolsTodayProvider);
      ref.invalidate(guardMyPatrolsProvider);
      ref.invalidate(guardDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Checkpoint logged'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(userFacingMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptLocation(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Main gate, Block A entrance',
            labelText: 'Location',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<_CheckpointInput?> _promptCheckpoint() async {
    final locCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool issuesFound = false;

    final result = await showDialog<_CheckpointInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log checkpoint'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: locCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Parking B2, Pool area',
                    labelText: 'Location',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Optional notes',
                    labelText: 'Notes',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Issues found'),
                  value: issuesFound,
                  onChanged: (v) =>
                      setDialogState(() => issuesFound = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final loc = locCtrl.text.trim();
                if (loc.isNotEmpty) {
                  Navigator.pop(
                    ctx,
                    _CheckpointInput(
                      location: loc,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      issuesFound: issuesFound,
                    ),
                  );
                }
              },
              child: const Text('Log'),
            ),
          ],
        ),
      ),
    );
    locCtrl.dispose();
    notesCtrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayAsync = ref.watch(guardPatrolsTodayProvider);
    final historyAsync = ref.watch(guardMyPatrolsProvider);

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text('Patrols', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GuardTokens.padScreen,
                GuardTokens.g2,
                GuardTokens.padScreen,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GuardScreenSectionHeader(
                    icon: Icons.shield_rounded,
                    title: 'Patrol log',
                    subtitle:
                        'Start a patrol round or log checkpoints as you go',
                  ),
                  const SizedBox(height: GuardTokens.g2),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _startPatrol,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start patrol'),
                        ),
                      ),
                      const SizedBox(width: GuardTokens.g2),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _logCheckpoint,
                          icon: const Icon(Icons.pin_drop_rounded),
                          label: const Text('Checkpoint'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: GuardTokens.g2),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: GuardTokens.g2),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GuardTokens.padScreen,
              ),
              child: Text(
                'Today',
                style: GuardTokens.headingStyle(context)
                    .copyWith(fontSize: GuardTokens.body),
              ),
            ),
            const SizedBox(height: GuardTokens.g1),
            Expanded(
              child: todayAsync.when(
                loading: () => const GuardListSkeleton(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  child: Center(
                    child: GuardInlineErrorBanner(
                      message: userFacingMessage(e),
                      onRetry: () =>
                          ref.invalidate(guardPatrolsTodayProvider),
                    ),
                  ),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(GuardTokens.padScreen),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 52,
                              color: GuardTokens.textSecondary
                                  .withValues(alpha: 0.85),
                            ),
                            const SizedBox(height: GuardTokens.g2),
                            Text(
                              'No patrols today',
                              style: GuardTokens.headingStyle(context),
                            ),
                            const SizedBox(height: GuardTokens.g1),
                            Text(
                              'Tap "Start patrol" to begin a round.',
                              textAlign: TextAlign.center,
                              style: GuardTokens.bodyStyle(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(guardPatrolsTodayProvider);
                      ref.invalidate(guardMyPatrolsProvider);
                      await ref.read(guardPatrolsTodayProvider.future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        GuardTokens.padScreen,
                        0,
                        GuardTokens.padScreen,
                        GuardTokens.g3,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (_, i) =>
                          _PatrolCard(patrol: rows[i]),
                    ),
                  );
                },
              ),
            ),
            // Recent history section (collapsed)
            historyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (rows) {
                // Filter out today's entries — only show history
                final now = DateTime.now();
                final history = rows.where((p) {
                  final d = p.scheduledTime ?? p.createdAt;
                  if (d == null) return true;
                  return d.day != now.day ||
                      d.month != now.month ||
                      d.year != now.year;
                }).toList();
                if (history.isEmpty) return const SizedBox.shrink();
                return _RecentHistory(patrols: history);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointInput {
  const _CheckpointInput({
    required this.location,
    this.notes,
    this.issuesFound = false,
  });

  final String location;
  final String? notes;
  final bool issuesFound;
}

class _PatrolCard extends StatelessWidget {
  const _PatrolCard({required this.patrol});

  final GuardPatrolRow patrol;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (patrol.isInProgress) {
      statusColor = GuardTokens.guardAccentDeep;
      statusIcon = Icons.directions_walk_rounded;
      statusLabel = 'In progress';
    } else if (patrol.isCompleted) {
      statusColor = GuardTokens.success;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Completed';
    } else if (patrol.isMissed) {
      statusColor = GuardTokens.dangerBrand;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Missed';
    } else {
      statusColor = GuardTokens.textSecondary;
      statusIcon = Icons.schedule_rounded;
      statusLabel = 'Scheduled';
    }

    final time = patrol.actualTime ?? patrol.scheduledTime;
    final timeStr = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Card(
      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.g2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(GuardTokens.g1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius:
                    BorderRadius.circular(GuardTokens.radiusChip),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: GuardTokens.g2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patrol.checkpointName,
                    style: GuardTokens.headingStyle(context)
                        .copyWith(fontSize: GuardTokens.body),
                  ),
                  if (patrol.checkpointLocation != null &&
                      patrol.checkpointLocation!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      patrol.checkpointLocation!,
                      style: GuardTokens.captionStyle(context),
                    ),
                  ],
                  if (patrol.notes != null &&
                      patrol.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      patrol.notes!,
                      style: GuardTokens.captionStyle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: GuardTokens.g1),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: GuardTokens.captionStyle(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GuardTokens.g1,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(GuardTokens.radiusChip),
                  ),
                  child: Text(
                    statusLabel,
                    style: GuardTokens.captionStyle(context).copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: GuardTokens.caption - 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentHistory extends StatefulWidget {
  const _RecentHistory({required this.patrols});

  final List<GuardPatrolRow> patrols;

  @override
  State<_RecentHistory> createState() => _RecentHistoryState();
}

class _RecentHistoryState extends State<_RecentHistory> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GuardTokens.padScreen,
              vertical: GuardTokens.g1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent history (${widget.patrols.length})',
                    style: GuardTokens.headingStyle(context)
                        .copyWith(fontSize: GuardTokens.body),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: GuardTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              GuardTokens.padScreen,
              0,
              GuardTokens.padScreen,
              GuardTokens.g2,
            ),
            itemCount: widget.patrols.length.clamp(0, 20),
            itemBuilder: (_, i) =>
                _PatrolCard(patrol: widget.patrols[i]),
          ),
      ],
    );
  }
}
