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
    return const ShimmerWrap(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: DesignSpacing.screenPaddingH,
          vertical: DesignSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Greeting header --
            Row(
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

            SizedBox(height: DesignSpacing.xl),

            // -- Stats row (3 chips) --
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg)),
              ],
            ),

            SizedBox(height: DesignSpacing.xl),

            // -- Quick actions grid (2x2) --
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
              ],
            ),
            SizedBox(height: DesignSpacing.sm),
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 88, borderRadius: DesignRadius.xl)),
              ],
            ),

            SizedBox(height: DesignSpacing.xl),

            // -- Hero card --
            ShimmerBox(height: 140, borderRadius: DesignRadius.xl),

            SizedBox(height: DesignSpacing.xl),

            // -- Section header --
            ShimmerBox(height: 14, width: 120, borderRadius: DesignRadius.sm),

            SizedBox(height: DesignSpacing.md),

            // -- List items --
            ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
            SizedBox(height: DesignSpacing.sm),
            ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
            SizedBox(height: DesignSpacing.sm),
            ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
          ],
        ),
      ),
    );
  }
}
