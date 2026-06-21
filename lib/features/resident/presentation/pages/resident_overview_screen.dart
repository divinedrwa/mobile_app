import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../data/models/resident_dashboard_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/dashboard_provider.dart';
import '../../data/providers/maintenance_provider.dart';
import 'amenity_booking_history_screen.dart';
import 'parcel_management_screen.dart';

const Color _kPageBg = DesignColors.background;
const Color _kOverviewOrange = Color(0xFFF39C12); // Brand warning amber
const Color _kCardBg = Colors.white;
const Color _kBorderColor = Color(0xFFE8ECF0);

/// Full overview — opened from Home "View all".
/// Enterprise-level dashboard with animated stats and professional design.
class ResidentOverviewScreen extends ConsumerWidget {
  const ResidentOverviewScreen({super.key});

  static int _attentionTotal(ResidentDashboardStats s, {bool excludeMaintenance = false}) =>
      (excludeMaintenance ? 0 : s.pendingMaintenance) + s.activeComplaints + s.pendingParcels + s.upcomingBookings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userExcluded = ref.watch(authProvider).user?.isBillingExcluded ?? false;
    final billingExcludedFromCycle = ref.watch(residentBillingCycleProvider).maybeWhen(
      data: (c) => c.maintenanceBillingExcluded,
      orElse: () => false,
    );
    final isBillingExcluded = userExcluded || billingExcludedFromCycle;
    final dash = ref.watch(residentDashboardProvider);
    final stats = dash.valueOrNull?.stats;
    final isInitialLoad = dash.isLoading && stats == null;
    final s = stats ??
        const ResidentDashboardStats(
          pendingMaintenance: 0,
          activeComplaints: 0,
          pendingParcels: 0,
          upcomingBookings: 0,
        );
    final total = stats != null
        ? _attentionTotal(s, excludeMaintenance: isBillingExcluded)
        : 0;

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
            // Enhanced App Bar with gradient
            SliverAppBar.large(
              pinned: true,
              backgroundColor: _kCardBg,
              surfaceTintColor: Colors.transparent,
              foregroundColor: DesignColors.textPrimary,
              elevation: 0,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              flexibleSpace: FlexibleSpaceBar(
                expandedTitleScale: 1.0,
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: DesignColors.textPrimary,
                        fontSize: 28,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your activity snapshot',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textSecondary.withValues(alpha: 0.85),
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _kCardBg,
                        DesignColors.primary.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error state
                    if (dash.hasError) ...[
                      _OverviewErrorChip(onRetry: () => ref.invalidate(residentDashboardProvider))
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 14),
                    ],
                    
                    if (isInitialLoad) ...[
                      const StatsRowSkeleton(),
                    ] else ...[
                    // Hero summary card with animation
                    _EnhancedHeroSummaryCard(
                      stats: s,
                      attentionTotal: total,
                      isBillingExcluded: isBillingExcluded,
                    )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 50.ms)
                      .slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 28),
                    
                    // Section header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                DesignColors.primary,
                                DesignColors.primary.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Detailed metrics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: DesignColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: DesignColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorderColor),
                          ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: total > 0 ? _kOverviewOrange : DesignColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        total > 0 ? 'Active' : 'Clear',
                        style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: DesignColors.textSecondary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms)
                      .slideX(begin: -0.1, end: 0),
                    
                    const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            
            // Metric tiles with staggered animation
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: isInitialLoad
                  ? const SliverToBoxAdapter(child: StatsRowSkeleton())
                  : SliverList(
                delegate: SliverChildListDelegate([
                  if (!isBillingExcluded) ...[
                    _EnhancedMetricTile(
                      icon: Icons.payments_rounded,
                      color: _kOverviewOrange,
                      title: 'Maintenance',
                      value: s.pendingMaintenance,
                      subtitle: 'Pending maintenance items',
                      onTap: () => context.push('/resident/maintenance'),
                      index: 0,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _EnhancedMetricTile(
                    icon: Icons.report_problem_rounded,
                    color: const Color(0xFFE65100),
                    title: 'Complaints',
                    value: s.activeComplaints,
                    subtitle: 'Active complaints you raised',
                    onTap: () => context.push('/resident/my-complaints'),
                    index: isBillingExcluded ? 0 : 1,
                  ),
                  const SizedBox(height: 14),
                  _EnhancedMetricTile(
                    icon: Icons.inventory_2_rounded,
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
                    index: isBillingExcluded ? 1 : 2,
                  ),
                  const SizedBox(height: 14),
                  _EnhancedMetricTile(
                    icon: Icons.event_available_rounded,
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
                    index: isBillingExcluded ? 2 : 3,
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

// ============================================================================
// ERROR CHIP
// ============================================================================

class _OverviewErrorChip extends StatelessWidget {
  const _OverviewErrorChip({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cloud_off_rounded, color: Colors.orange.shade900, size: 18),
              ),
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
              Icon(Icons.refresh_rounded, color: Colors.orange.shade900, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ENHANCED HERO SUMMARY CARD
// ============================================================================

class _EnhancedHeroSummaryCard extends StatelessWidget {
  const _EnhancedHeroSummaryCard({
    required this.stats,
    required this.attentionTotal,
    this.isBillingExcluded = false,
  });

  final ResidentDashboardStats stats;
  final int attentionTotal;
  final bool isBillingExcluded;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (!isBillingExcluded && stats.pendingMaintenance > 0) {
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
        ? (isBillingExcluded
            ? 'No pending parcels or open complaints in these counters.'
            : 'No pending maintenance, parcels, or open complaints in these counters.')
        : (lines.length <= 2
            ? lines.join(' · ')
            : '${lines.take(2).join(' · ')} · +${lines.length - 2} more');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kCardBg,
            DesignColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: DesignColors.primary.withValues(alpha: 0.03),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top gradient accent bar
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DesignColors.primary,
                  DesignColors.primary.withValues(alpha: 0.7),
                  const Color(0xFF00897B),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon and headline
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: attentionTotal > 0
                            ? _kOverviewOrange.withValues(alpha: 0.1)
                            : DesignColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: attentionTotal > 0
                              ? _kOverviewOrange.withValues(alpha: 0.2)
                              : DesignColors.success.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        attentionTotal > 0 ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                        color: attentionTotal > 0 ? _kOverviewOrange : DesignColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.2,
                              color: DesignColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: DesignColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 18),
                
                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kBorderColor.withValues(alpha: 0.3),
                        _kBorderColor,
                        _kBorderColor.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 18),
                
                // Stats grid
                Row(
                  children: [
                    if (!isBillingExcluded) ...[
                      Expanded(
                        child: _StatPill(
                          label: 'Maintenance',
                          value: stats.pendingMaintenance,
                          color: _kOverviewOrange,
                          icon: Icons.payments_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _StatPill(
                        label: 'Complaints',
                        value: stats.activeComplaints,
                        color: const Color(0xFFE65100),
                        icon: Icons.report_problem_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: 'Parcels',
                        value: stats.pendingParcels,
                        color: DesignColors.primary,
                        icon: Icons.inventory_2_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        label: 'Bookings',
                        value: stats.upcomingBookings,
                        color: const Color(0xFF00897B),
                        icon: Icons.event_available_rounded,
                      ),
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

// ============================================================================
// STAT PILL
// ============================================================================

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: DesignColors.textSecondary,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedCounter(
                  value: value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.0,
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

// ============================================================================
// ENHANCED METRIC TILE
// ============================================================================

class _EnhancedMetricTile extends StatelessWidget {
  const _EnhancedMetricTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
    required this.index,
  });

  final IconData icon;
  final Color color;
  final String title;
  final int value;
  final String subtitle;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Icon circle with gradient
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                
                const SizedBox(width: 16),
                
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DesignColors.textPrimary,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: DesignColors.textSecondary.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Value and arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCounter(
                      value: value,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        height: 1.0,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: DesignColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
      .animate()
      .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 200 + (index * 80)))
      .slideX(begin: 0.1, end: 0);
  }
}
