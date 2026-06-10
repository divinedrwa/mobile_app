import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/animated_counter.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/resident_dashboard_model.dart';
import '../../pages/amenity_booking_history_screen.dart';
import '../../pages/parcel_management_screen.dart';
class HomeDashboardStatsRow extends ConsumerWidget {
  const HomeDashboardStatsRow({
    super.key,
    required this.dashboardAsync,
    this.isBillingExcluded = false,
  });

  final AsyncValue<ResidentDashboardModel> dashboardAsync;
  final bool isBillingExcluded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallbackStats = ResidentDashboardStats(
      pendingMaintenance: 0,
      activeComplaints: 0,
      pendingParcels: 0,
      upcomingBookings: 0,
    );
    final s = dashboardAsync.maybeWhen(
      data: (d) => d.stats,
      orElse: () => fallbackStats,
    );

    final tiles = <_TileSpec>[
      if (!isBillingExcluded)
        _TileSpec(
          label: 'Maintenance',
          value: s.pendingMaintenance,
          color: const Color(0xFF5C6BC0),
          icon: Icons.build_outlined,
          onTap: () => context.push('/resident/maintenance'),
        ),
      _TileSpec(
        label: 'Complaints',
        value: s.activeComplaints,
        color: const Color(0xFFE65100),
        icon: Icons.report_problem_outlined,
        onTap: () => context.push('/resident/my-complaints'),
      ),
      _TileSpec(
        label: 'Parcels',
        value: s.pendingParcels,
        color: DesignColors.primary,
        icon: Icons.inventory_2_outlined,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const ParcelManagementScreen()),
        ),
      ),
      _TileSpec(
        label: 'Bookings',
        value: s.upcomingBookings,
        color: const Color(0xFF5C6BC0),
        icon: Icons.event_available_outlined,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const AmenityBookingHistoryScreen()),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.38,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _interleavedTiles(context, tiles),
        ),
      ],
    );
  }

  List<Widget> _interleavedTiles(
      BuildContext context, List<_TileSpec> tiles) {
    final list = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) list.add(const SizedBox(width: 6));
      list.add(Expanded(child: _tile(context, tiles[i])));
    }
    return list;
  }

  Widget _tile(BuildContext context, _TileSpec spec) {
    return Container(
      decoration: DesignComponents.cardDecoration(
        color: context.surface.defaultSurface,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DesignRadius.borderLG,
          onTap: () {
            DesignHaptics.selection();
            spec.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 10),
            child: Row(
              children: [
                // Rounded-square icon
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(spec.icon,
                      color: spec.color, size: 15),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCounter(
                        value: spec.value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: DesignColors.textPrimary,
                          height: 1.1,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: context.text.secondary,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: DesignColors.primary,
                              ),
                            ),
                            const SizedBox(width: 1),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 11,
                              color: DesignColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileSpec {
  const _TileSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
}
