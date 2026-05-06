import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Reusable section title row for guard full-screen flows.
class GuardScreenSectionHeader extends StatelessWidget {
  const GuardScreenSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: GuardTokens.guardAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GuardTokens.headingStyle(context).copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: GuardTokens.captionStyle(context)),
        ],
      ],
    );
  }
}
