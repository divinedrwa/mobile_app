import 'package:flutter/material.dart';

import 'design_animations.dart';

/// App-wide page route transition: a subtle slide-up + fade.
///
/// Wired into [ThemeData.pageTransitionsTheme] so **every** `MaterialPage`
/// route (which is what GoRouter's `builder:` produces) animates consistently
/// without touching individual routes.
///
/// Design intent:
/// * Forward: incoming page fades in while rising a few percent of the screen.
/// * Back: reverses on [curveExit] for a natural dismissal.
/// * Honors the OS "reduce motion" accessibility setting (no transform/fade).
///
/// iOS/macOS deliberately keep [CupertinoPageTransitionsBuilder] so the
/// platform-expected interactive swipe-to-go-back gesture is preserved.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Respect "reduce motion" — skip straight to the content.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: DesignAnimations.curveEntrance, // easeOutCubic
      reverseCurve: DesignAnimations.curveExit, // easeInCubic
    );

    final offset = Tween<Offset>(
      begin: const Offset(0, 0.035), // ~3.5% of height — subtle, premium
      end: Offset.zero,
    ).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: offset, child: child),
    );
  }
}

/// [PageTransitionsTheme] applied to every [ThemeData] the app builds.
///
/// Custom fade+slide on platforms whose default transition we want to replace;
/// Cupertino on Apple platforms to keep the swipe-back gesture.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeSlidePageTransitionsBuilder(),
    TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
    TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);
