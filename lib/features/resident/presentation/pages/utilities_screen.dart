import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/garbage_collection_model.dart';
import '../../data/models/water_request_model.dart';
import '../../data/models/water_supply_model.dart';
import '../../data/providers/utilities_provider.dart';

class UtilitiesScreen extends ConsumerStatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  ConsumerState<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends ConsumerState<UtilitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        title: const Text('Society Utilities'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DesignColors.primary,
          unselectedLabelColor: context.text.secondary,
          indicatorColor: DesignColors.primary,
          tabs: const [
            Tab(text: 'Water Supply'),
            Tab(text: 'Garbage Collection'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WaterSupplyTab(),
          _GarbageCollectionTab(),
        ],
      ),
    );
  }
}

class _WaterSupplyTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(waterSupplyStatusProvider);
    final eventsAsync = ref.watch(waterSupplyEventsProvider);
    final requestsAsync = ref.watch(waterSupplyMyRequestsProvider);

    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () async {
        ref.invalidate(waterSupplyStatusProvider);
        ref.invalidate(waterSupplyEventsProvider);
        ref.invalidate(waterSupplyMyRequestsProvider);
      },
      child: statusAsync.when(
        loading: () => _buildShimmer(),
        error: (err, _) => _buildError(context, err, ref),
        data: (gates) {
          if (gates.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                EmptyStateWidget(
                  icon: Icons.water_drop_outlined,
                  title: 'No water supply data',
                  subtitle: 'Water supply information will appear here.',
                  actionLabel: 'Refresh',
                  onAction: () => ref.invalidate(waterSupplyStatusProvider),
                ),
              ],
            );
          }
          final events = eventsAsync.valueOrNull ?? [];
          final requests = requestsAsync.valueOrNull ?? [];
          return ListView(
            padding: const EdgeInsets.all(DesignSpacing.lg),
            children: [
              // Request Water button
              OutlinedButton.icon(
                onPressed: () => _showWaterRequestSheet(context, ref, gates),
                icon: const Icon(Icons.water_drop_rounded),
                label: const Text('Request Water'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignColors.primary,
                  side: BorderSide(color: DesignColors.primary),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: DesignSpacing.md),
              // Gate status cards
              ...gates.asMap().entries.map((entry) {
                return _buildGateStatusCard(context, entry.value, entry.key);
              }),
              // My Requests section
              if (requests.isNotEmpty) ...[
                const SizedBox(height: DesignSpacing.xl),
                Text(
                  'My Requests',
                  style: DesignTypography.headingM.copyWith(
                    color: context.text.primary,
                  ),
                ),
                const SizedBox(height: DesignSpacing.sm),
                ...requests.take(5).toList().asMap().entries.map((entry) {
                  return _buildRequestTile(context, entry.value, entry.key);
                }),
              ],
              // Recent Activity
              if (events.isNotEmpty) ...[
                const SizedBox(height: DesignSpacing.xl),
                Text(
                  'Recent Activity',
                  style: DesignTypography.headingM.copyWith(
                    color: context.text.primary,
                  ),
                ),
                const SizedBox(height: DesignSpacing.sm),
                ...events.asMap().entries.map((entry) {
                  return _buildEventTile(context, entry.value, entry.key);
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showWaterRequestSheet(
      BuildContext context, WidgetRef ref, List<WaterSupplyStatus> gates) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WaterRequestSheet(gates: gates),
    );
  }

  Widget _buildGateStatusCard(
      BuildContext context, WaterSupplyStatus gate, int index) {
    final tone = gate.isOn ? EnterpriseTone.success : EnterpriseTone.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
      child: EnterprisePanel(
        tone: tone,
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gate.isOn
                    ? DesignColors.success.withValues(alpha: 0.12)
                    : DesignColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignRadius.md),
              ),
              child: Icon(
                Icons.water_drop_rounded,
                color: gate.isOn ? DesignColors.success : DesignColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: DesignSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gate.gateName.isNotEmpty ? gate.gateName : 'Gate',
                    style: DesignTypography.headingM.copyWith(
                      color: context.text.primary,
                    ),
                  ),
                  if (gate.location.isNotEmpty)
                    Text(
                      gate.location,
                      style: DesignTypography.bodySmall.copyWith(
                        color: context.text.secondary,
                      ),
                    ),
                  if (!gate.isOn && gate.reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        gate.reason!,
                        style: DesignTypography.caption.copyWith(
                          color: DesignColors.error,
                        ),
                      ),
                    ),
                  if (gate.lastChanged != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${gate.isOn ? "On" : "Off"} for ${_durationSince(gate.lastChanged!)}',
                        style: DesignTypography.caption.copyWith(
                          color: context.text.tertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gate.isOn
                    ? DesignColors.success.withValues(alpha: 0.15)
                    : DesignColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignRadius.full),
              ),
              child: Text(
                gate.isOn ? 'ON' : 'OFF',
                style: DesignTypography.labelSmall.copyWith(
                  color: gate.isOn ? DesignColors.success : DesignColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: DesignAnimations.staggerFor(index))
        .slideY(
          begin: DesignAnimations.slideNormal,
          end: 0,
          duration: DesignAnimations.durationEntrance,
        )
        .fadeIn();
  }

  Widget _buildRequestTile(
      BuildContext context, WaterRequestModel req, int index) {
    final statusColor = req.isPending
        ? DesignColors.warning
        : req.isFulfilled
            ? DesignColors.success
            : DesignColors.error;
    final statusLabel = req.isPending
        ? 'PENDING'
        : req.isFulfilled
            ? 'FULFILLED'
            : 'REJECTED';
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: EnterprisePanel(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.md,
          vertical: DesignSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              req.isTurnOn ? Icons.water_drop_rounded : Icons.block_rounded,
              color: req.isTurnOn ? DesignColors.primary : DesignColors.error,
              size: 18,
            ),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${req.gateName} - ${req.isTurnOn ? "Turn ON" : "Turn OFF"}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    req.reason,
                    style: DesignTypography.caption.copyWith(
                      color: context.text.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (req.resolvedNote != null && req.resolvedNote!.isNotEmpty)
                    Text(
                      'Note: ${req.resolvedNote}',
                      style: DesignTypography.captionSmall.copyWith(
                        color: context.text.tertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignRadius.full),
              ),
              child: Text(
                statusLabel,
                style: DesignTypography.captionSmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: DesignAnimations.staggerFor(index))
        .fadeIn(duration: DesignAnimations.durationEntrance);
  }

  Widget _buildEventTile(
      BuildContext context, WaterSupplyEvent event, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: EnterprisePanel(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.md,
          vertical: DesignSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              event.turnedOn
                  ? Icons.water_drop_rounded
                  : Icons.block_rounded,
              color: event.turnedOn
                  ? DesignColors.success
                  : DesignColors.error,
              size: 18,
            ),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${event.gateName} - ${event.turnedOn ? "Turned ON" : "Turned OFF"}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (event.reason != null)
                    Text(
                      event.reason!,
                      style: DesignTypography.caption.copyWith(
                        color: context.text.secondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _relativeTime(event.createdAt),
              style: DesignTypography.caption.copyWith(
                color: context.text.tertiary,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: DesignAnimations.staggerFor(index))
        .fadeIn(duration: DesignAnimations.durationEntrance);
  }

  Widget _buildShimmer() {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          children: [
            const ShimmerBox(height: 44),
            const SizedBox(height: DesignSpacing.md),
            const ShimmerBox(height: 100),
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 100),
            const SizedBox(height: DesignSpacing.xl),
            const ShimmerBox(height: 20, width: 120),
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 50),
            const SizedBox(height: DesignSpacing.xs),
            const ShimmerBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object err, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: DesignColors.error, size: 48),
          const SizedBox(height: DesignSpacing.sm),
          Text(
            'Failed to load water supply data',
            style: DesignTypography.body.copyWith(color: context.text.secondary),
          ),
          const SizedBox(height: DesignSpacing.sm),
          TextButton(
            onPressed: () => ref.invalidate(waterSupplyStatusProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _GarbageCollectionTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(garbageCollectionActiveProvider);
    final historyAsync = ref.watch(garbageCollectionHistoryProvider);

    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () async {
        ref.invalidate(garbageCollectionActiveProvider);
        ref.invalidate(garbageCollectionHistoryProvider);
      },
      child: historyAsync.when(
        loading: () => _buildShimmer(),
        error: (err, _) => _buildError(context, ref),
        data: (history) {
          final active = activeAsync.valueOrNull;
          if (history.isEmpty && (active == null || !active.isInside)) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                EmptyStateWidget(
                  icon: Icons.delete_outline_rounded,
                  title: 'No collection data',
                  subtitle: 'Garbage collection history will appear here.',
                  actionLabel: 'Refresh',
                  onAction: () =>
                      ref.invalidate(garbageCollectionHistoryProvider),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(DesignSpacing.lg),
            children: [
              // Weekly summary
              if (history.isNotEmpty) _buildWeeklySummary(context, history),
              if (active != null && active.isInside && active.activeEvent != null)
                _buildActiveCard(context, active.activeEvent!),
              if (history.isNotEmpty) ...[
                const SizedBox(height: DesignSpacing.md),
                Text(
                  'Recent History',
                  style: DesignTypography.headingM.copyWith(
                    color: context.text.primary,
                  ),
                ),
                const SizedBox(height: DesignSpacing.sm),
                ...history.asMap().entries.map((entry) {
                  return _buildHistoryTile(context, entry.value, entry.key);
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeeklySummary(
      BuildContext context, List<GarbageCollectionEvent> history) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeek = history.where((e) {
      return e.entryTime.isAfter(weekStart);
    }).toList();

    if (thisWeek.isEmpty) return const SizedBox.shrink();

    final completedDurations = thisWeek
        .where((e) => e.duration != null)
        .map((e) => e.duration!.inMinutes)
        .toList();
    final avgMin = completedDurations.isNotEmpty
        ? (completedDurations.reduce((a, b) => a + b) /
                completedDurations.length)
            .round()
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.md),
      child: EnterprisePanel(
        tone: EnterpriseTone.info,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.md,
          vertical: DesignSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: context.text.secondary),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(
              child: Text(
                'This week: ${thisWeek.length} collection${thisWeek.length != 1 ? 's' : ''}${avgMin > 0 ? ', avg $avgMin min' : ''}',
                style: DesignTypography.bodySmall.copyWith(
                  color: context.text.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance);
  }

  Widget _buildActiveCard(BuildContext context, GarbageCollectionEvent event) {
    return EnterprisePanel(
      tone: EnterpriseTone.warning,
      padding: const EdgeInsets.all(DesignSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: DesignColors.warning,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then()
              .fadeOut(duration: 800.ms),
          const SizedBox(width: DesignSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collector Inside',
                  style: DesignTypography.headingM.copyWith(
                    color: context.text.primary,
                  ),
                ),
                Text(
                  'Entered at ${DateFormat.jm().format(event.entryTime.toLocal())} via ${event.gateName}',
                  style: DesignTypography.bodySmall.copyWith(
                    color: context.text.secondary,
                  ),
                ),
                Text(
                  'Duration: ${_formatDuration(event.duration)}',
                  style: DesignTypography.caption.copyWith(
                    color: context.text.tertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.delete_sweep_rounded,
            color: DesignColors.warning,
            size: 28,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance)
        .scaleXY(
          begin: 0.95,
          end: 1.0,
          duration: DesignAnimations.durationEmphasis,
          curve: DesignAnimations.curveEntrance,
        );
  }

  Widget _buildHistoryTile(
      BuildContext context, GarbageCollectionEvent event, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: EnterprisePanel(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.md,
          vertical: DesignSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: context.text.tertiary,
              size: 20,
            ),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMd().format(event.entryTime.toLocal()),
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${event.gateName} - ${DateFormat.jm().format(event.entryTime.toLocal())} \u2192 ${event.exitTime != null ? DateFormat.jm().format(event.exitTime!.toLocal()) : "Still inside"}',
                    style: DesignTypography.caption.copyWith(
                      color: context.text.secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (event.duration != null)
              Text(
                _formatDuration(event.duration),
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                ),
              ),
          ],
        ),
      ),
    )
        .animate(delay: DesignAnimations.staggerFor(index))
        .fadeIn(duration: DesignAnimations.durationEntrance);
  }

  Widget _buildShimmer() {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          children: [
            const ShimmerBox(height: 80),
            const SizedBox(height: DesignSpacing.md),
            const ShimmerBox(height: 20, width: 120),
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 50),
            const SizedBox(height: DesignSpacing.xs),
            const ShimmerBox(height: 50),
            const SizedBox(height: DesignSpacing.xs),
            const ShimmerBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: DesignColors.error, size: 48),
          const SizedBox(height: DesignSpacing.sm),
          Text(
            'Failed to load data',
            style: DesignTypography.body.copyWith(color: context.text.secondary),
          ),
          const SizedBox(height: DesignSpacing.sm),
          TextButton(
            onPressed: () =>
                ref.invalidate(garbageCollectionHistoryProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for submitting a water supply request.
class _WaterRequestSheet extends ConsumerStatefulWidget {
  const _WaterRequestSheet({required this.gates});
  final List<WaterSupplyStatus> gates;

  @override
  ConsumerState<_WaterRequestSheet> createState() => _WaterRequestSheetState();
}

class _WaterRequestSheetState extends ConsumerState<_WaterRequestSheet> {
  late String _selectedGateId;
  String _requestType = 'TURN_ON';
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedGateId = widget.gates.first.gateId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason (min 3 chars)')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(utilitiesRepositoryProvider);
      await repo.submitWaterRequest(
        gateId: _selectedGateId,
        requestType: _requestType,
        reason: reason,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water request submitted')),
        );
        ref.invalidate(waterSupplyMyRequestsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Request Water Supply',
            style: DesignTypography.headingM.copyWith(
              color: context.text.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Gate selector
          DropdownButtonFormField<String>(
            value: _selectedGateId,
            decoration: const InputDecoration(
              labelText: 'Gate',
              border: OutlineInputBorder(),
            ),
            items: widget.gates
                .map((g) => DropdownMenuItem(
                      value: g.gateId,
                      child: Text(g.gateName.isNotEmpty ? g.gateName : 'Gate'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedGateId = v);
            },
          ),
          const SizedBox(height: 12),
          // Request type toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Turn ON'),
                  selected: _requestType == 'TURN_ON',
                  selectedColor: DesignColors.success.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      setState(() => _requestType = 'TURN_ON'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Turn OFF'),
                  selected: _requestType == 'TURN_OFF',
                  selectedColor: DesignColors.error.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      setState(() => _requestType = 'TURN_OFF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reason
          TextField(
            controller: _reasonController,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Why do you need this change?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.water_drop_rounded),
              label: const Text('Submit Request'),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final local = dt.toLocal();
  final diff = DateTime.now().difference(dt);
  final clock = DateFormat.jm().format(local);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago \u00b7 $clock';
  if (diff.inHours < 24) return '${diff.inHours}h ago \u00b7 $clock';
  if (diff.inDays < 7) return '${diff.inDays}d ago \u00b7 $clock';
  return '${DateFormat.yMMMd().format(local)} \u00b7 $clock';
}

String _formatDuration(Duration? d) {
  if (d == null) return '';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}

String _durationSince(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) {
    final m = diff.inMinutes % 60;
    return m > 0 ? '${diff.inHours}h ${m}m' : '${diff.inHours}h';
  }
  if (diff.inDays < 7) return '${diff.inDays}d ${diff.inHours % 24}h';
  return 'since ${DateFormat.MMMd().format(dt.toLocal())}';
}
