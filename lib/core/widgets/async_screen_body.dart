import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_exception_mapper.dart';
import '../theme/design_tokens.dart';
import 'async_animated_switcher.dart';
import 'enterprise_ui.dart';
import 'shimmer_box.dart';
import '../../theme/context_extensions.dart';

/// Standard async page body: skeleton while loading, retry banner on error.
///
/// Use for list/detail screens instead of [CircularProgressIndicator] or blank
/// [SizedBox.shrink] during fetch.
class AsyncScreenBody<T> extends StatelessWidget {
  const AsyncScreenBody({
    super.key,
    required this.asyncValue,
    required this.onRetry,
    required this.builder,
    this.skeleton,
    this.errorTitle = 'Could not load',
    this.backgroundColor,
  });

  final AsyncValue<T> asyncValue;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final Widget? skeleton;
  final String errorTitle;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Crossfade between loading → content → error so the swap is smooth
    // instead of an abrupt jump (shared logic in [AsyncValueAnimatedX]).
    return ColoredBox(
      color: backgroundColor ?? context.surface.background,
      child: asyncValue.whenAnimated(
        loading: () => skeleton ?? const _DefaultListShimmer(),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: EdgeInsets.all(context.spacing.s16),
              child: EnterpriseInfoBanner(
                icon: Icons.error_outline_rounded,
                title: errorTitle,
                message: userFacingMessage(error),
                tone: EnterpriseTone.danger,
                actionLabel: 'Retry',
                onAction: onRetry,
              ),
            ),
          ],
        ),
        data: builder,
      ),
    );
  }
}

class _DefaultListShimmer extends StatelessWidget {
  const _DefaultListShimmer();

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView(
        padding: EdgeInsets.all(context.spacing.s16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: List.generate(
          5,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < 4 ? 10 : 0),
            child: const ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
          ),
        ),
      ),
    );
  }
}
