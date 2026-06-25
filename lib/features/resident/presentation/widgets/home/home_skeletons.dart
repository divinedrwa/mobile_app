import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import 'home_shared.dart';

/// Two compact utility / status chips in a row.
class HomeUtilityStripSkeleton extends StatelessWidget {
  const HomeUtilityStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ShimmerWrap(
        child: Row(
          children: [
            Expanded(
              child: ShimmerBox(height: 52, borderRadius: kHomeRadiusMd),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShimmerBox(height: 52, borderRadius: kHomeRadiusMd),
            ),
          ],
        ),
      ),
    );
  }
}

/// Security / support call strip.
class HomeSupportStripSkeleton extends StatelessWidget {
  const HomeSupportStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DesignColors.surfaceSoft,
          borderRadius: BorderRadius.circular(kHomeRadiusLg),
          border: Border.all(color: DesignColors.borderLight),
        ),
        child: Row(
          children: [
            const ShimmerBox(width: 32, height: 32, borderRadius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(height: 12, width: 160, borderRadius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(height: 10, width: 110, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShimmerBox(height: 30, width: 96, borderRadius: kHomeRadiusMd),
          ],
        ),
      ),
    );
  }
}

/// Gate visitor approval card.
class HomeGateRequestSkeleton extends StatelessWidget {
  const HomeGateRequestSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: DesignColors.surfaceSoft,
          borderRadius: BorderRadius.circular(kHomeRadiusMd),
          border: Border.all(color: DesignColors.borderLight),
        ),
        child: Row(
          children: [
            const ShimmerBox(width: 36, height: 36, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(height: 13, width: 140, borderRadius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(height: 10, width: 200, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ShimmerBox(width: 22, height: 22, borderRadius: 11),
          ],
        ),
      ),
    );
  }
}

/// Maintenance card skeleton — matches mock (green header + nested white card).
class HomeMaintenanceCardSkeleton extends StatelessWidget {
  const HomeMaintenanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Shell gradient mirrors the live card: mint green top → white.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDF3E7), Colors.white],
          stops: [0.0, 0.55],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE8D9)),
        boxShadow: homeCardShadow(0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: ShimmerWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDDF3E7), Color(0xFFF0FAF5)],
                ),
              ),
              child: Row(
                children: [
                  const ShimmerBox(width: 44, height: 44, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(height: 15, width: 155, borderRadius: 6),
                        SizedBox(height: 6),
                        ShimmerBox(height: 10, width: 200, borderRadius: 6),
                      ],
                    ),
                  ),
                  const ShimmerBox(width: 44, height: 44, borderRadius: 10),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4EBF0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      for (var i = 0; i < 2; i++) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              const ShimmerBox(
                                width: 40,
                                height: 40,
                                borderRadius: 11,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    ShimmerBox(
                                      height: 12,
                                      width: 120,
                                      borderRadius: 6,
                                    ),
                                    SizedBox(height: 6),
                                    ShimmerBox(
                                      height: 10,
                                      width: 185,
                                      borderRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const ShimmerBox(
                                width: 18,
                                height: 18,
                                borderRadius: 9,
                              ),
                            ],
                          ),
                        ),
                        if (i == 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 66, right: 14),
                            child: Divider(
                              height: 1,
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(left: 66, right: 14),
                        child: Divider(
                          height: 1,
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      Container(
                        color: const Color(0xFFFFF1F0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: const ShimmerBox(
                          height: 12,
                          borderRadius: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent activity list inside a card.
class HomeRecentActivitySkeleton extends StatelessWidget {
  const HomeRecentActivitySkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Column(
        children: List.generate(rows, (i) {
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const ShimmerBox(width: 44, height: 44, borderRadius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerBox(height: 13, width: 140, borderRadius: 6),
                          SizedBox(height: 8),
                          ShimmerBox(height: 11, borderRadius: 6),
                          SizedBox(height: 4),
                          ShimmerBox(height: 11, width: 200, borderRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShimmerBox(height: 26, width: 52, borderRadius: 20),
                  ],
                ),
              ),
              if (i < rows - 1)
                const Divider(height: 1, color: DesignColors.borderLight),
            ],
          );
        }),
      ),
    );
  }
}

/// Single-line subtitle placeholder for section headers.
class HomeSectionSubtitleSkeleton extends StatelessWidget {
  const HomeSectionSubtitleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerWrap(
      child: ShimmerBox(height: 10, width: 120, borderRadius: 6),
    );
  }
}
