import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_animations.dart';

/// Crossfade between an [AsyncValue]'s loading / error / data widgets.
extension AsyncValueAnimatedX<T> on AsyncValue<T> {
  /// Like [AsyncValue.when], but wraps the result in an [AnimatedSwitcher] so
  /// the loading → content → error swap fades smoothly instead of snapping.
  ///
  /// Each branch is given a distinct key so the switcher detects the change.
  ///
  /// ⚠️ Use only when every branch returns a BOX widget (ListView, Column,
  /// Padding, RefreshIndicator…). If a branch returns a sliver, use the plain
  /// `.when` — a sliver cannot live inside an [AnimatedSwitcher].
  Widget whenAnimated({
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace stackTrace) error,
    required Widget Function(T data) data,
    Duration duration = DesignAnimations.durationEntrance,
    bool skipLoadingOnReload = false,
  }) {
    // On a reload of an already-cached provider, keep showing the data branch
    // (via the previous value) instead of flashing back to the skeleton.
    if (skipLoadingOnReload && isLoading && valueOrNull != null) {
      return AnimatedSwitcher(
        duration: duration,
        switchInCurve: DesignAnimations.curveEntrance,
        switchOutCurve: DesignAnimations.curveExit,
        child: KeyedSubtree(
          key: const ValueKey('async-data'),
          child: data(valueOrNull as T),
        ),
      );
    }

    final Widget child = when(
      loading: () => KeyedSubtree(
        key: const ValueKey('async-loading'),
        child: loading(),
      ),
      error: (e, s) => KeyedSubtree(
        key: const ValueKey('async-error'),
        child: error(e, s),
      ),
      data: (d) => KeyedSubtree(
        key: const ValueKey('async-data'),
        child: data(d),
      ),
    );

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: DesignAnimations.curveEntrance,
      switchOutCurve: DesignAnimations.curveExit,
      child: child,
    );
  }
}
