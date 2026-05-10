import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/shimmer_box.dart';

/// Shimmer skeleton matching the home screen's actual layout.
///
/// Shows: greeting header + 3 stat chips + quick actions grid +
/// hero card + 2 list items. Gives users spatial context while loading.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.screenPaddingH,
          vertical: DesignSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Greeting header --
            const Row(
              children: [
                ShimmerBox(width: 44, height: 44, borderRadius: 22),
                SizedBox(width: DesignSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 16, width: 140, borderRadius: DesignRadius.sm),
                      SizedBox(height: DesignSpacing.sm),
                      ShimmerBox(height: 12, width: 100, borderRadius: DesignRadius.sm),
                    ],
                  ),
                ),
                ShimmerBox(width: 36, height: 36, borderRadius: 18),
              ],
            ),

            const SizedBox(height: DesignSpacing.xl),

            // -- Stats row (3 chips) --
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg)),
              ],
            ),

            const SizedBox(height: DesignSpacing.xl),

            // -- Quick actions grid (2x2) --
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
              ],
            ),
            const SizedBox(height: DesignSpacing.sm),
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
              ],
            ),

            const SizedBox(height: DesignSpacing.xl),

            // -- Hero card --
            const ShimmerBox(height: 140, borderRadius: DesignRadius.xl),

            const SizedBox(height: DesignSpacing.xl),

            // -- Section header --
            const ShimmerBox(height: 14, width: 120, borderRadius: DesignRadius.sm),

            const SizedBox(height: DesignSpacing.md),

            // -- List items --
            const ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
          ],
        ),
      ),
    );
  }
}
