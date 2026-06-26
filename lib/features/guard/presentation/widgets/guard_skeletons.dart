import 'package:flutter/material.dart';

import '../../../../core/widgets/shimmer_box.dart';
import '../../ui/guard_tokens.dart';

/// Skeleton for list-based guard tabs (visitors, deliveries, vehicles, logs).
/// Shows a summary chip + N card placeholders.
class GuardListSkeleton extends StatelessWidget {
  const GuardListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShimmerBox(height: 36, borderRadius: 10),
            const SizedBox(height: GuardTokens.g2),
            for (int i = 0; i < itemCount; i++) ...[
              const _ListItemSkeleton(),
              if (i < itemCount - 1) const SizedBox(height: GuardTokens.g2),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListItemSkeleton extends StatelessWidget {
  const _ListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ShimmerBox(width: 44, height: 44, borderRadius: 22),
        SizedBox(width: GuardTokens.g2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 14, borderRadius: 6),
              SizedBox(height: 8),
              ShimmerBox(height: 11, borderRadius: 6, width: 120),
            ],
          ),
        ),
        SizedBox(width: GuardTokens.g2),
        ShimmerBox(width: 48, height: 24, borderRadius: 8),
      ],
    );
  }
}

/// Skeleton for shift roster screen.
class GuardShiftSkeleton extends StatelessWidget {
  const GuardShiftSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShimmerBox(height: 20, borderRadius: 6, width: 140),
            const SizedBox(height: 4),
            const ShimmerBox(height: 12, borderRadius: 6, width: 200),
            const SizedBox(height: GuardTokens.sectionGap),
            for (int i = 0; i < 4; i++) ...[
              const _ShiftCardSkeleton(),
              if (i < 3) const SizedBox(height: GuardTokens.g2),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftCardSkeleton extends StatelessWidget {
  const _ShiftCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GuardTokens.g2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(color: GuardTokens.borderSubtle),
      ),
      child: const Row(
        children: [
          ShimmerBox(width: 42, height: 42, borderRadius: 10),
          SizedBox(width: GuardTokens.g2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14, borderRadius: 6),
                SizedBox(height: 8),
                ShimmerBox(height: 11, borderRadius: 6, width: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for the residents directory list.
class GuardDirectorySkeleton extends StatelessWidget {
  const GuardDirectorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < 6; i++) ...[
              const _DirectoryCardSkeleton(),
              if (i < 5) const SizedBox(height: GuardTokens.g2),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectoryCardSkeleton extends StatelessWidget {
  const _DirectoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ShimmerBox(width: 52, height: 52, borderRadius: 26),
        SizedBox(width: GuardTokens.g2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 14, borderRadius: 6),
              SizedBox(height: 8),
              ShimmerBox(height: 11, borderRadius: 6, width: 100),
            ],
          ),
        ),
        SizedBox(width: GuardTokens.g1),
        Column(
          children: [
            ShimmerBox(width: 48, height: 48, borderRadius: 12),
            SizedBox(height: GuardTokens.g1),
            ShimmerBox(width: 48, height: 48, borderRadius: 12),
          ],
        ),
      ],
    );
  }
}

/// Skeleton for today summary — metric grid + pending banner + outcome card.
class GuardSummarySkeleton extends StatelessWidget {
  const GuardSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerWrap(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: GuardTokens.padScreen,
          vertical: GuardTokens.g1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShimmerBox(height: 12, borderRadius: 6, width: 160),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 60, borderRadius: GuardTokens.radiusCard)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 60, borderRadius: GuardTokens.radiusCard)),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 60, borderRadius: GuardTokens.radiusCard)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 60, borderRadius: GuardTokens.radiusCard)),
              ],
            ),
            SizedBox(height: 14),
            ShimmerBox(height: 48, borderRadius: GuardTokens.radiusCard),
            SizedBox(height: 18),
            ShimmerBox(height: 14, borderRadius: 6, width: 200),
            SizedBox(height: 10),
            ShimmerBox(height: 120, borderRadius: GuardTokens.radiusCard),
          ],
        ),
      ),
    );
  }
}
