import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Reusable section title row for guard full-screen flows.
class GuardScreenSectionHeader extends StatelessWidget {
  const GuardScreenSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: GuardTokens.guardAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GuardTokens.headingStyle(context).copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              GestureDetector(
                onTap: onAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GuardTokens.guardAccentDeep,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: GuardTokens.guardAccentDeep,
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GuardTokens.captionStyle(context).copyWith(
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
