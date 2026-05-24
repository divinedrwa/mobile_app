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

    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () async {
        ref.invalidate(waterSupplyStatusProvider);
        ref.invalidate(waterSupplyEventsProvider);
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
          return ListView(
            padding: const EdgeInsets.all(DesignSpacing.lg),
            children: [
              ...gates.asMap().entries.map((entry) {
                return _buildGateStatusCard(context, entry.value, entry.key);
              }),
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
                        'Updated ${_relativeTime(gate.lastChanged!)}',
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
                    '${event.gateName} - ${DateFormat.jm().format(event.entryTime.toLocal())} → ${event.exitTime != null ? DateFormat.jm().format(event.exitTime!.toLocal()) : "Still inside"}',
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

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(dt.toLocal());
}

String _formatDuration(Duration? d) {
  if (d == null) return '';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}
