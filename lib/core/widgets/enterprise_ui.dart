import 'package:flutter/material.dart';

import '../../theme/context_extensions.dart';

enum EnterpriseTone { neutral, success, warning, danger, info }

class EnterprisePanel extends StatelessWidget {
  const EnterprisePanel({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.tone = EnterpriseTone.neutral,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EnterpriseTone tone;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(context, tone);
    final backgroundColor = _backgroundColor(context, tone);
    final radius = BorderRadius.circular(context.radius.lg);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: padding ??
            EdgeInsets.all(
              context.spacing.s16,
            ),
        child: child,
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

class EnterpriseSectionHeader extends StatelessWidget {
  const EnterpriseSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.text.primary,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.text.secondary,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                SizedBox(height: context.spacing.s4),
                Text(subtitle!, style: subtitleStyle),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class EnterpriseInfoBanner extends StatelessWidget {
  const EnterpriseInfoBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = EnterpriseTone.info,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final EnterpriseTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(context, tone);

    return EnterprisePanel(
      tone: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(context.radius.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.$2, size: 22),
          ),
          SizedBox(width: context.spacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.text.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: context.spacing.s4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.text.secondary,
                      ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: context.spacing.s8),
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EnterpriseActionTile extends StatelessWidget {
  const EnterpriseActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.tone = EnterpriseTone.neutral,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EnterpriseTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(context, tone);

    return EnterprisePanel(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(context.radius.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.$2, size: 22),
          ),
          SizedBox(width: context.spacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.text.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: context.spacing.s4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.text.secondary,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.s12),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: context.text.tertiary,
              ),
        ],
      ),
    );
  }
}

(Color, Color) _toneColors(BuildContext context, EnterpriseTone tone) {
  switch (tone) {
    case EnterpriseTone.success:
      return (context.state.approved.bg, context.state.approved.solid);
    case EnterpriseTone.warning:
      return (context.state.pending.bg, context.state.pending.solid);
    case EnterpriseTone.danger:
      return (context.state.denied.bg, context.state.denied.solid);
    case EnterpriseTone.info:
      return (context.state.info.bg, context.state.info.solid);
    case EnterpriseTone.neutral:
      return (context.surface.elevated, context.brand.primary);
  }
}

Color _borderColor(BuildContext context, EnterpriseTone tone) {
  switch (tone) {
    case EnterpriseTone.success:
      return context.state.approved.solid.withValues(alpha: 0.22);
    case EnterpriseTone.warning:
      return context.state.pending.solid.withValues(alpha: 0.22);
    case EnterpriseTone.danger:
      return context.state.denied.solid.withValues(alpha: 0.22);
    case EnterpriseTone.info:
      return context.state.info.solid.withValues(alpha: 0.22);
    case EnterpriseTone.neutral:
      return context.surface.border;
  }
}

Color _backgroundColor(BuildContext context, EnterpriseTone tone) {
  switch (tone) {
    case EnterpriseTone.success:
      return context.state.approved.bg.withValues(alpha: 0.45);
    case EnterpriseTone.warning:
      return context.state.pending.bg.withValues(alpha: 0.42);
    case EnterpriseTone.danger:
      return context.state.denied.bg.withValues(alpha: 0.38);
    case EnterpriseTone.info:
      return context.state.info.bg.withValues(alpha: 0.42);
    case EnterpriseTone.neutral:
      return context.surface.defaultSurface;
  }
}
