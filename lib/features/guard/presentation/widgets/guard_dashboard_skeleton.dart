import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../ui/guard_tokens.dart';

/// Skeleton loading for the guard home dashboard (thumb-friendly layout).
class GuardDashboardSkeleton extends StatelessWidget {
  const GuardDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.symmetric(
        horizontal: GuardTokens.padScreen,
        vertical: GuardTokens.g2,
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? GuardTokens.darkBorder : base,
        highlightColor: isDark ? GuardTokens.darkCard : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _box(h: 120, r: GuardTokens.radiusLg),
            const SizedBox(height: GuardTokens.sectionGap),
            Row(
              children: [
                Expanded(child: _box(h: 88, r: GuardTokens.radiusCard)),
                const SizedBox(width: GuardTokens.g2),
                Expanded(child: _box(h: 88, r: GuardTokens.radiusCard)),
                const SizedBox(width: GuardTokens.g2),
                Expanded(child: _box(h: 88, r: GuardTokens.radiusCard)),
              ],
            ),
            const SizedBox(height: GuardTokens.sectionGap),
            Row(
              children: [
                Expanded(child: _box(h: GuardTokens.heroQuickActionMinHeight, r: GuardTokens.radiusLg)),
                const SizedBox(width: GuardTokens.g2),
                Expanded(child: _box(h: GuardTokens.heroQuickActionMinHeight, r: GuardTokens.radiusLg)),
              ],
            ),
            const SizedBox(height: GuardTokens.g2),
            Row(
              children: [
                Expanded(child: _box(h: GuardTokens.heroQuickActionMinHeight, r: GuardTokens.radiusLg)),
                const SizedBox(width: GuardTokens.g2),
                Expanded(child: _box(h: GuardTokens.heroQuickActionMinHeight, r: GuardTokens.radiusLg)),
              ],
            ),
            const SizedBox(height: GuardTokens.sectionGap),
            _box(h: 18, r: 6),
            const SizedBox(height: GuardTokens.g2),
            _box(h: 72, r: GuardTokens.radiusCard),
            const SizedBox(height: GuardTokens.g2),
            _box(h: 72, r: GuardTokens.radiusCard),
          ],
        ),
      ),
    );
  }

  Widget _box({required double h, required double r}) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}
