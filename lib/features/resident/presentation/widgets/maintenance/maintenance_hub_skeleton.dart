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
          horizontal: DesignSpacing.lg + 4, // 20px
          vertical: DesignSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Hero status card --
            ShimmerBox(height: 140, borderRadius: DesignRadius.xl),

            SizedBox(height: DesignSpacing.lg),

            // -- Stat chips row (3) --
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 52, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 52, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 52, borderRadius: DesignRadius.lg)),
              ],
            ),

            SizedBox(height: DesignSpacing.lg),

            // -- Shortcut cards (2) --
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 52, borderRadius: DesignRadius.lg)),
                SizedBox(width: DesignSpacing.sm),
                Expanded(child: ShimmerBox(height: 52, borderRadius: DesignRadius.lg)),
              ],
            ),

            SizedBox(height: DesignSpacing.lg + 4),

            // -- Section header --
            ShimmerBox(height: 14, width: 140, borderRadius: DesignRadius.sm),

            SizedBox(height: DesignSpacing.md),

            // -- Payment list items --
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
