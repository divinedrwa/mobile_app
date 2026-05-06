import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/models/resident_dashboard_model.dart';
import '../../data/providers/dashboard_provider.dart';
import 'amenity_booking_history_screen.dart';
import 'parcel_management_screen.dart';

const Color _kPageBg = Color(0xFFF8F9FB);
const Color _kOverviewOrange = Color(0xFFFF6D00);

/// Full overview — opened from Home “View all”.
class ResidentOverviewScreen extends ConsumerWidget {
  const ResidentOverviewScreen({super.key});

  static int _attentionTotal(ResidentDashboardStats s) =>
      s.pendingMaintenance + s.activeComplaints + s.pendingParcels + s.upcomingBookings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(residentDashboardProvider);
    final fallback = const ResidentDashboardStats(
      pendingMaintenance: 0,
      activeComplaints: 0,
      pendingParcels: 0,
      upcomingBookings: 0,
    );
    final s = dash.maybeWhen(data: (d) => d.stats, orElse: () => fallback);
    final total = _attentionTotal(s);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () async {
          ref.invalidate(residentDashboardProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              foregroundColor: DesignColors.textPrimary,
              elevation: 0,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              flexibleSpace: FlexibleSpaceBar(
                expandedTitleScale: 1.0,
                titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
                title: Text(
                  'Overview',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                    color: DesignColors.textPrimary,
                    fontSize: 22,
                  ),
                ),
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        DesignColors.primary.withValues(alpha: 0.07),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dash.hasError) ...[
                      _OverviewErrorChip(onRetry: () => ref.invalidate(residentDashboardProvider)),
                      const SizedBox(height: 14),
                    ],
                    _HeroSummaryCard(stats: s, attentionTotal: total),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: DesignColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your metrics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: DesignColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _OverviewMetricTile(
                    icon: Icons.payments_outlined,
                    color: _kOverviewOrange,
                    title: 'Maintenance',
                    value: s.pendingMaintenance,
                    subtitle: 'Pending maintenance items',
                    onTap: () => context.push('/resident/maintenance-payment'),
                  ),
                  const SizedBox(height: 12),
                  _OverviewMetricTile(
                    icon: Icons.report_problem_outlined,
                    color: const Color(0xFFE65100),
                    title: 'Complaints',
                    value: s.activeComplaints,
                    subtitle: 'Active complaints you raised',
                    onTap: () => context.push('/resident/my-complaints'),
                  ),
                  const SizedBox(height: 12),
                  _OverviewMetricTile(
                    icon: Icons.inventory_2_outlined,
                    color: DesignColors.primary,
                    title: 'Parcels',
                    value: s.pendingParcels,
                    subtitle: 'Deliveries waiting at gate / desk',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ParcelManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _OverviewMetricTile(
                    icon: Icons.event_available_outlined,
                    color: const Color(0xFF00897B),
                    title: 'Bookings',
                    value: s.upcomingBookings,
                    subtitle: 'Upcoming amenity reservations',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AmenityBookingHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewErrorChip extends StatelessWidget {
  const _OverviewErrorChip({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: Colors.orange.shade900, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Couldn\'t refresh latest counts. Showing cached values — tap to retry.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              Icon(Icons.refresh_rounded, color: Colors.orange.shade900, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({
    required this.stats,
    required this.attentionTotal,
  });

  final ResidentDashboardStats stats;
  final int attentionTotal;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (stats.pendingMaintenance > 0) {
      lines.add('${stats.pendingMaintenance} maintenance');
    }
    if (stats.activeComplaints > 0) {
      lines.add('${stats.activeComplaints} complaints');
    }
    if (stats.pendingParcels > 0) {
      lines.add('${stats.pendingParcels} parcels');
    }
    if (stats.upcomingBookings > 0) {
      lines.add('${stats.upcomingBookings} bookings');
    }

    final headline = attentionTotal == 0
        ? 'You\'re all caught up'
        : '$attentionTotal ${attentionTotal == 1 ? 'item' : 'items'} need attention';

    final detail = attentionTotal == 0
        ? 'No pending maintenance, parcels, or open complaints in these counters.'
        : (lines.length <= 2
            ? lines.join(' · ')
            : '${lines.take(2).join(' · ')} · +${lines.length - 2} more');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DesignColors.primary,
                  DesignColors.primary.withValues(alpha: 0.65),
                  const Color(0xFF00897B),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: DesignColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStatChip(
                      label: 'Maint.',
                      value: stats.pendingMaintenance,
                      color: _kOverviewOrange,
                    ),
                    _MiniStatChip(
                      label: 'Compl.',
                      value: stats.activeComplaints,
                      color: const Color(0xFFE65100),
                    ),
                    _MiniStatChip(
                      label: 'Parcel',
                      value: stats.pendingParcels,
                      color: DesignColors.primary,
                    ),
                    _MiniStatChip(
                      label: 'Book',
                      value: stats.upcomingBookings,
                      color: const Color(0xFF00897B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.95),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DesignColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetricTile extends StatelessWidget {
  const _OverviewMetricTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final int value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: DesignColors.textPrimary,
                                  letterSpacing: -0.28,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: DesignColors.textSecondary.withValues(alpha: 0.92),
                                  height: 1.28,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$value',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.textPrimary,
                                height: 1.0,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: DesignColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
