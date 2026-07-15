part of '../admin_dashboard_screen.dart';

extension _AdminDashboardLoadingPart on _AdminDashboardScreenState {
  Widget _skeleton() {
    return ShimmerWrap(
      child: Column(
        children: [
          // Society fund card
          const ShimmerBox(height: 240, borderRadius: 16),
          const SizedBox(height: kAdminDashSectionGap),
          // Maintenance card
          const ShimmerBox(height: 160, borderRadius: 16),
          const SizedBox(height: kAdminDashSectionGap),
          // Summary strip
          const ShimmerBox(height: 130, borderRadius: 16),
          const SizedBox(height: kAdminDashSectionGap),
          // CTA
          const ShimmerBox(height: 72, borderRadius: 16),
          const SizedBox(height: kAdminDashSectionGap),
          // 3-column grid
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: List.generate(
                6, (_) => const ShimmerBox(height: 70, borderRadius: 14)),
          ),
        ],
      ),
    );
  }

  Widget _error() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: EmptyStateWidget(
        icon: Icons.error_outline_rounded,
        title: 'Failed to load dashboard',
        subtitle: 'Pull down to refresh or tap retry.',
        actionLabel: 'Retry',
        onAction: _handleRefresh,
      ),
    );
  }
}
