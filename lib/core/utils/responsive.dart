import 'package:flutter/widgets.dart';

/// Returns true when the viewport is wide enough for a desktop-style layout
/// (e.g. NavigationRail instead of bottom nav).
bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 720;

/// On wide screens, constrains [child] to a centered column (max 600 dp).
/// On narrow screens, passes [child] through unchanged.
class WebContentConstraint extends StatelessWidget {
  const WebContentConstraint({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isWideScreen(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }
}
