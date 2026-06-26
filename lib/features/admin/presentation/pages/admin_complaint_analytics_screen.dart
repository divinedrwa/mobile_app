import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for advanced complaint analytics.
class AdminComplaintAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminComplaintAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminComplaintAnalyticsScreen> createState() =>
      _AdminComplaintAnalyticsScreenState();
}

class _AdminComplaintAnalyticsScreenState
    extends ConsumerState<AdminComplaintAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminComplaintAnalyticsSummaryProvider);
    ref.invalidate(adminComplaintAnalyticsByCategoryProvider);
    ref.invalidate(adminComplaintAnalyticsPendingProvider);
    ref.invalidate(adminComplaintAnalyticsTrendProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminComplaintAnalyticsSummaryProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Complaint Analytics',
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
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: summaryAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: [
                  ShimmerBox(height: 100, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(
                          height: 48, borderRadius: DesignRadius.lg),
                    ),
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
                  title: 'Failed to load analytics',
                  subtitle: 'Something went wrong. Please try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (summary) => _buildBody(summary),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> summary) {
    final byCatAsync = ref.watch(adminComplaintAnalyticsByCategoryProvider);
    final pendingAsync = ref.watch(adminComplaintAnalyticsPendingProvider);
    final trendAsync = ref.watch(adminComplaintAnalyticsTrendProvider);

    final total = _toInt(summary['totalComplaints']);
    final resolved = _toInt(summary['resolvedComplaints']);
    final resRate = _toDouble(summary['resolutionRate']);
    final avgDays = _toDouble(summary['averageResolutionDays'] ??
        summary['averageResolutionTime']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Summary hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Complaint Summary (30 days)',
                    style: DesignTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _heroStat('Total', '$total'),
                  _heroStat('Resolved', '$resolved'),
                  _heroStat('Rate', '${resRate.round()}%'),
                  _heroStat('Avg Days', avgDays.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // By category
        EnterpriseSectionHeader(title: 'By Category'),
        const SizedBox(height: 8),
        byCatAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 100, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (categories) => _categoryList(categories),
        ),
        const SizedBox(height: 16),

        // Trend
        EnterpriseSectionHeader(title: '6-Month Trend'),
        const SizedBox(height: 8),
        trendAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (trend) => _trendCard(trend),
        ),
        const SizedBox(height: 16),

        // Pending
        EnterpriseSectionHeader(title: 'Pending Complaints'),
        const SizedBox(height: 8),
        pendingAsync.when(
          loading: () => ShimmerWrap(
            child: Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerBox(
                      height: 56, borderRadius: DesignRadius.lg),
                ),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (pending) {
            if (pending.isEmpty) {
              return EnterprisePanel(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No pending complaints',
                  style: DesignTypography.bodySmall
                      .copyWith(color: DesignColors.textSecondary),
                ),
              );
            }
            return Column(
              children: pending.take(10).toList().asMap().entries.map((e) => _pendingCard(e.value, e.key)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryList(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(14),
        child: Text(
          'No category data available',
          style: DesignTypography.bodySmall
              .copyWith(color: DesignColors.textSecondary),
        ),
      );
    }

    final maxCount = categories.fold<int>(
        0,
        (m, c) => _toInt(c['totalCount'] ?? c['count']) > m
            ? _toInt(c['totalCount'] ?? c['count'])
            : m);

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: categories.map((c) {
          final name = c['category']?.toString() ?? c['name']?.toString() ?? '';
          final count = _toInt(c['totalCount'] ?? c['count']);
          final fraction = maxCount > 0 ? count / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Uncategorized',
                      style: DesignTypography.captionSmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$count',
                      style: DesignTypography.captionSmall
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor:
                        const Color(0xFFEF4444).withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _trendCard(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(14),
        child: Text(
          'No trend data available',
          style: DesignTypography.bodySmall
              .copyWith(color: DesignColors.textSecondary),
        ),
      );
    }

    final maxCount = trend.fold<int>(
        0,
        (m, t) => _toInt(t['totalComplaints'] ?? t['count']) > m
            ? _toInt(t['totalComplaints'] ?? t['count'])
            : m);

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: trend.map((t) {
          final month = t['month']?.toString() ?? '';
          final count = _toInt(t['totalComplaints'] ?? t['count']);
          final fraction = maxCount > 0 ? count / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    month,
                    style: DesignTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 14,
                      backgroundColor:
                          const Color(0xFFEF4444).withValues(alpha: 0.08),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$count',
                    style: DesignTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> c, [int index = 0]) {
    final title = c['title']?.toString() ?? c['subject']?.toString() ?? '';
    final category = c['category']?.toString() ?? '';
    final priority = c['priority']?.toString().toUpperCase() ?? '';

    final prioColor = priority == 'HIGH' || priority == 'URGENT'
        ? const Color(0xFFEF4444)
        : priority == 'MEDIUM'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF3B82F6);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignTypography.label
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.isNotEmpty)
                  Text(
                    category,
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (priority.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: prioColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                priority,
                style: DesignTypography.captionSmall.copyWith(
                  color: prioColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
