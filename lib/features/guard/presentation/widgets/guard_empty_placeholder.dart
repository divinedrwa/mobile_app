import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Minimum height for tab scroll content when parent gives unbounded or zero
/// constraints (common with [IndexedStack] under nested navigators).
double guardTabScrollableMinHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  final pad = MediaQuery.paddingOf(context);
  const chrome =
      kToolbarHeight + 56 + 88; // app bar + sub-tabs + bottom nav (approx.)
  return (h - pad.top - pad.bottom - chrome).clamp(280.0, h);
}

/// Centered empty / offline placeholder for guard tabs (always visible, scrollable).
class GuardEmptyPlaceholder extends StatelessWidget {
  const GuardEmptyPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = iconColor ?? GuardTokens.guardAccentDeep;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: fg),
        ),
        const SizedBox(height: GuardTokens.g3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GuardTokens.headingStyle(context).copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: GuardTokens.textPrimary,
            height: 1.25,
          ),
        ),
        const SizedBox(height: GuardTokens.g2),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GuardTokens.bodyStyle(context).copyWith(
            height: 1.45,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: GuardTokens.g3),
          FilledButton(
            style: GuardTokens.primaryFilled(context),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

/// Pull-to-refresh wrapper that guarantees at least viewport height so empty states show.
Widget guardRefreshableMinHeight({
  required BuildContext context,
  required Future<void> Function() onRefresh,
  required List<Widget> children,
  EdgeInsetsGeometry? padding,
  ScrollController? scrollController,
}) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    color: GuardTokens.guardAccentDeep,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final fromParent = constraints.maxHeight;
        final minH = fromParent.isFinite && fromParent > 0
            ? fromParent
            : guardTabScrollableMinHeight(context);
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          primary: false,
          controller: scrollController,
          padding:
              padding ?? const EdgeInsets.all(GuardTokens.padScreen),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    ),
  );
}
