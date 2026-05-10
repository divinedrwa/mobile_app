import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/shimmer_box.dart';

/// Generic list skeleton usable for parcels, visitors, payments, complaints, etc.
///
/// Shows [itemCount] card-shaped shimmer placeholders.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.screenPaddingH,
          vertical: DesignSpacing.lg,
        ),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: DesignSpacing.sm),
        itemBuilder: (context, index) => ShimmerBox(
          height: itemHeight,
          borderRadius: DesignRadius.lg,
        ),
      ),
    );
  }
}
