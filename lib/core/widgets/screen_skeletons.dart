import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'shimmer_box.dart';

/// Horizontal stat chips (admin UPI, dashboard strips).
class ChipRowSkeleton extends StatelessWidget {
  const ChipRowSkeleton({super.key, this.count = 3, this.height = 36});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.screenPaddingH),
        child: Row(
          children: List.generate(
            count,
            (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                child: ShimmerBox(height: height, borderRadius: DesignRadius.lg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2×2 or row of metric cards (overview, dashboard).
class StatsRowSkeleton extends StatelessWidget {
  const StatsRowSkeleton({super.key, this.columns = 2, this.cardHeight = 88});

  final int columns;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.screenPaddingH),
        child: Column(
          children: [
            ShimmerBox(height: 120, borderRadius: DesignRadius.xl),
            const SizedBox(height: DesignSpacing.lg),
            for (var row = 0; row < 2; row++) ...[
              Row(
                children: List.generate(columns, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : DesignSpacing.sm,
                        right: i == columns - 1 ? 0 : 0,
                      ),
                      child: ShimmerBox(height: cardHeight, borderRadius: DesignRadius.lg),
                    ),
                  );
                }),
              ),
              if (row == 0) const SizedBox(height: DesignSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail / form screen: hero block + text lines.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key, this.heroHeight = 160});

  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DesignSpacing.screenPaddingH),
        children: [
          ShimmerBox(height: heroHeight, borderRadius: DesignRadius.xl),
          const SizedBox(height: DesignSpacing.lg),
          const ShimmerBox(height: 18, borderRadius: 6),
          const SizedBox(height: DesignSpacing.sm),
          const ShimmerBox(height: 14, borderRadius: 6, width: 220),
          const SizedBox(height: DesignSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            const ShimmerBox(height: 56, borderRadius: DesignRadius.lg),
            const SizedBox(height: DesignSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Compact picker lists (guard resident search, villa dropdown).
class PickerSkeleton extends StatelessWidget {
  const PickerSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(itemCount, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < itemCount - 1 ? DesignSpacing.sm : 0),
            child: const Row(
              children: [
                ShimmerBox(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: DesignSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 14, borderRadius: 6),
                      SizedBox(height: 6),
                      ShimmerBox(height: 11, borderRadius: 6, width: 100),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Vertical timeline / activity feed placeholder.
class TimelineSkeleton extends StatelessWidget {
  const TimelineSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(height: 14, borderRadius: 6, width: 120),
          const SizedBox(height: 10),
          for (var i = 0; i < itemCount; i++) ...[
            const ShimmerBox(height: 52, borderRadius: DesignRadius.lg),
            if (i < itemCount - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Banner / alert strip while loading (shifts, UPI alert).
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key, this.height = 52});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ShimmerBox(height: height, borderRadius: DesignRadius.lg),
    );
  }
}

/// Horizontal card carousel placeholder (special projects on home).
class CardCarouselSkeleton extends StatelessWidget {
  const CardCarouselSkeleton({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.screenPaddingH),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: DesignSpacing.sm),
          itemBuilder: (_, __) => SizedBox(
            width: 280,
            child: ShimmerBox(height: height, borderRadius: DesignRadius.xl),
          ),
        ),
      ),
    );
  }
}
