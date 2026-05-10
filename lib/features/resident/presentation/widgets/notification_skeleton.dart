import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/shimmer_box.dart';

/// Shimmer skeleton for the notification center list.
class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.screenPaddingH,
          vertical: DesignSpacing.lg,
        ),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(height: DesignSpacing.sm),
        itemBuilder: (context, index) => _notificationRow(),
      ),
    );
  }

  Widget _notificationRow() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 40, height: 40, borderRadius: 20),
        SizedBox(width: DesignSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 14, borderRadius: DesignRadius.sm),
              SizedBox(height: DesignSpacing.sm),
              ShimmerBox(height: 12, width: 200, borderRadius: DesignRadius.sm),
              SizedBox(height: DesignSpacing.xs),
              ShimmerBox(height: 10, width: 80, borderRadius: DesignRadius.sm),
            ],
          ),
        ),
      ],
    );
  }
}
