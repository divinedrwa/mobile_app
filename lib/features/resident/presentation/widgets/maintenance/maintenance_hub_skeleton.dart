import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';

/// Shimmer skeleton matching the maintenance hub layout.
///
/// Shows: hero status card + 3 stat chips + 2 shortcut cards + list items.
class MaintenanceHubSkeleton extends StatelessWidget {
  const MaintenanceHubSkeleton({super.key});

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
            // -- Hero status card --
            ShimmerBox(height: 160, borderRadius: DesignRadius.xl),

            SizedBox(height: DesignSpacing.xl),

            // -- Stat chips row (3) --
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg)),
              ],
            ),

            SizedBox(height: DesignSpacing.xl),

            // -- Shortcut cards (2) --
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 80, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 80, borderRadius: DesignRadius.lg)),
              ],
            ),

            SizedBox(height: DesignSpacing.xl),

            // -- Section header --
            ShimmerBox(height: 14, width: 140, borderRadius: DesignRadius.sm),

            SizedBox(height: DesignSpacing.md),

            // -- Payment list items --
            ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
            SizedBox(height: DesignSpacing.sm),
            ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
            SizedBox(height: DesignSpacing.sm),
            ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
          ],
        ),
      ),
    );
  }
}
