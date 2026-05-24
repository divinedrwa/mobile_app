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
import '../../data/models/vehicle_log_model.dart';
import '../../data/providers/vehicle_log_provider.dart';

class VehicleLogScreen extends ConsumerStatefulWidget {
  const VehicleLogScreen({super.key});

  @override
  ConsumerState<VehicleLogScreen> createState() => _VehicleLogScreenState();
}

class _VehicleLogScreenState extends ConsumerState<VehicleLogScreen> {
  String _filter = 'all'; // all, inside, exited

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(vehicleLogProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(title: const Text('Vehicle Log')),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () async => ref.invalidate(vehicleLogProvider),
        child: logAsync.when(
          loading: () => _buildShimmer(),
          error: (err, _) => _buildError(context),
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyStateWidget(
                    icon: Icons.directions_car_outlined,
                    title: 'No vehicle entries',
                    subtitle:
                        'Gate entry/exit logs for your registered vehicles will appear here.',
                    actionLabel: 'Refresh',
                    onAction: () => ref.invalidate(vehicleLogProvider),
                  ),
                ],
              );
            }

            final insideNow =
                entries.where((e) => e.isInside).toList();
            final filtered = _applyFilter(entries);
            final grouped = _groupByDate(filtered);

            return ListView(
              padding: const EdgeInsets.all(DesignSpacing.lg),
              children: [
                if (insideNow.isNotEmpty)
                  ...insideNow.map((e) => _buildInsideCard(context, e)),
                const SizedBox(height: DesignSpacing.sm),
                _buildFilterChips(context),
                const SizedBox(height: DesignSpacing.md),
                ...grouped.entries.expand((group) {
                  return [
                    Padding(
                      padding: const EdgeInsets.only(
                          top: DesignSpacing.sm, bottom: DesignSpacing.xs),
                      child: Text(
                        group.key,
                        style: DesignTypography.label.copyWith(
                          color: context.text.tertiary,
                        ),
                      ),
                    ),
                    ...group.value.asMap().entries.map((entry) {
                      return _buildEntryCard(context, entry.value, entry.key);
                    }),
                  ];
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  List<VehicleLogEntry> _applyFilter(List<VehicleLogEntry> all) {
    switch (_filter) {
      case 'inside':
        return all.where((e) => e.isInside).toList();
      case 'exited':
        return all.where((e) => !e.isInside).toList();
      default:
        return all;
    }
  }

  Map<String, List<VehicleLogEntry>> _groupByDate(
      List<VehicleLogEntry> entries) {
    final map = <String, List<VehicleLogEntry>>{};
    for (final e in entries) {
      final key = DateFormat.yMMMd().format(e.entryAt.toLocal());
      (map[key] ??= []).add(e);
    }
    return map;
  }

  Widget _buildFilterChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _filterChip(context, 'All', 'all'),
        _filterChip(context, 'Inside', 'inside'),
        _filterChip(context, 'Exited', 'exited'),
      ],
    );
  }

  Widget _filterChip(BuildContext context, String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        if (s) setState(() => _filter = value);
      },
      selectedColor: DesignColors.primary.withValues(alpha: 0.15),
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: selected ? DesignColors.primary : context.text.secondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? DesignColors.primary : context.surface.border,
      ),
    );
  }

  Widget _buildInsideCard(BuildContext context, VehicleLogEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
      child: EnterprisePanel(
        tone: EnterpriseTone.warning,
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignRadius.md),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: DesignColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: DesignSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.registrationNumber,
                    style: DesignTypography.headingM.copyWith(
                      color: context.text.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Inside since ${DateFormat.jm().format(entry.entryAt.toLocal())}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DesignColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignRadius.full),
              ),
              child: Text(
                'INSIDE',
                style: DesignTypography.captionSmall.copyWith(
                  color: DesignColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildEntryCard(
      BuildContext context, VehicleLogEntry entry, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: EnterprisePanel(
        padding: const EdgeInsets.all(DesignSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.directions_car_outlined,
              color: context.text.tertiary,
              size: 22,
            ),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.registrationNumber,
                        style: DesignTypography.bodyMedium.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              context.brand.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(DesignRadius.xs),
                        ),
                        child: Text(
                          entry.kind,
                          style: DesignTypography.captionSmall.copyWith(
                            color: context.brand.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat.jm().format(entry.entryAt.toLocal())} → ${entry.exitAt != null ? DateFormat.jm().format(entry.exitAt!.toLocal()) : "Still inside"}',
                    style: DesignTypography.caption.copyWith(
                      color: context.text.secondary,
                    ),
                  ),
                  if (entry.guardName != null)
                    Text(
                      'Guard: ${entry.guardName}',
                      style: DesignTypography.caption.copyWith(
                        color: context.text.tertiary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _formatDuration(entry.duration),
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
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 30, width: 200),
            const SizedBox(height: DesignSpacing.md),
            const ShimmerBox(height: 60),
            const SizedBox(height: DesignSpacing.xs),
            const ShimmerBox(height: 60),
            const SizedBox(height: DesignSpacing.xs),
            const ShimmerBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: DesignColors.error, size: 48),
          const SizedBox(height: DesignSpacing.sm),
          Text(
            'Failed to load vehicle log',
            style:
                DesignTypography.body.copyWith(color: context.text.secondary),
          ),
          const SizedBox(height: DesignSpacing.sm),
          TextButton(
            onPressed: () => ref.invalidate(vehicleLogProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}
