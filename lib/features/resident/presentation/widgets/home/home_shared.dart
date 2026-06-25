import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';

// ── Constants (were file-private _k* in home_screen.dart) ──

const Color kHomeOrange = Color(0xFFF39C12);
const Color kHomeGreen = DesignColors.primary;

/// Mock-aligned accent purple for GatePass+ hero and home CTAs.
const Color kHomePurple = Color(0xFF6C5CE7);
const Color kHomePurpleDark = Color(0xFF5B4BD4);
const Color kHomePurpleLight = Color(0xFFF3F0FF);

const double kHomePadH = 16;
const double kHomeSectionGap = 14;
const double kHomeHeroRowHeight = 108;
const double kHomeRadiusCard = 14;
const double kHomeRadiusLg = DesignRadius.xl; // 16
const double kHomeRadiusMd = DesignRadius.lg; // 12
const double kHomeRadiusSm = DesignRadius.md; // 8

/// Subtle elevation for enterprise cards (no heavy glow).
List<BoxShadow> homeCardShadow([double opacity = 0.045]) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];

// ── Shared helpers ──

String homeTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ── Shared widgets ──

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.subtitle,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  /// When null the "View All" button is hidden.
  final VoidCallback? onViewAll;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: subtitle != null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: dense ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                  letterSpacing: -0.3,
                  height: dense ? 1.1 : 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: DesignColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: kHomePurple,
            padding: EdgeInsets.fromLTRB(4, dense ? 0 : 4, 0, dense ? 0 : 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity:
                dense ? VisualDensity.compact : VisualDensity.standard,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: dense ? 1.1 : 1.2,
                  color: kHomePurple,
                ),
              ),
              const SizedBox(width: 1),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: kHomePurple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeEmptyBlock extends StatelessWidget {
  const HomeEmptyBlock({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: DesignComponents.cardDecoration(
        color: context.surface.defaultSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.text.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.text.secondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
