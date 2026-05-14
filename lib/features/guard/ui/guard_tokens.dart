import 'package:flutter/material.dart';

/// Guard-only UI tokens (8px grid). Does not alter global [AppTheme].
/// Apply via [GuardThemeScope] under `/guard/*`.
abstract final class GuardTokens {
  // —— Grid ——
  static const double g1 = 8;
  static const double g2 = 16;
  static const double g3 = 24;
  static const double padScreen = 18; // 16–20px
  static const double sectionGap = 22; // 20–24px

  // —— Radii ——
  static const double radiusCard = 14;
  static const double radiusButton = 12;
  static const double radiusChip = 10;

  // —— Buttons (heights per spec — not oversized) ——
  static const double btnPrimaryH = 50; // 48–52
  static const double btnSecondaryH = 42; // 40–44

  // —— Typography ——
  static const double title = 19; // 18–20 semi-bold → use w600
  static const double body = 15; // 14–16
  static const double caption = 12.5; // 12–13

  // —— Outdoor-readable contrast ——
  static const Color guardAccent = Color(0xFF6B7280);
  static const Color guardAccentDeep = Color(0xFF374151);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE5E7EB);

  static const Color darkSurface = Color(0xFF1A1F2E);
  static const Color darkCard = Color(0xFF252B3A);
  static const Color darkBorder = Color(0xFF334155);

  /// Semantic accents (premium guard UI — dark mode uses softer variants inline).
  static const Color success = Color(0xFF16A34A);
  static const Color successMuted = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF97316);
  static const Color warningMuted = Color(0xFFFFEDD5);
  static const Color dangerBrand = Color(0xFFDC2626);
  static const Color dangerMuted = Color(0xFFFEE2E2);

  static const double radiusLg = 16;
  static const double heroQuickActionMinHeight = 108;
  static const double iconHero = 32;

  static List<BoxShadow> softCardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static ButtonStyle primaryFilled(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(btnPrimaryH),
      padding: const EdgeInsets.symmetric(horizontal: g2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusButton),
      ),
      foregroundColor: Colors.white,
      backgroundColor:
          isDark ? guardAccent : guardAccentDeep,
    );
  }

  static ButtonStyle secondaryOutlined(BuildContext context) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(btnSecondaryH),
      padding: const EdgeInsets.symmetric(horizontal: g2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusButton),
      ),
    );
  }

  /// Use with [TextButton] only — do not use [secondaryOutlined] (that style is for [OutlinedButton]).
  static ButtonStyle textLink(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton.styleFrom(
      foregroundColor: isDark ? guardAccent : guardAccentDeep,
      padding: const EdgeInsets.symmetric(horizontal: g1, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static TextStyle _fallbackHeading(BuildContext context) => TextStyle(
        fontSize: title,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle _fallbackBody() => const TextStyle(
        fontSize: body,
        color: textSecondary,
      );

  static TextStyle headingStyle(BuildContext context, {Color? color}) {
    final t = Theme.of(context).textTheme;
    final base = t.titleMedium ?? t.titleLarge ?? t.bodyLarge ?? _fallbackHeading(context);
    return base.copyWith(
          fontSize: title,
          fontWeight: FontWeight.w600,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        );
  }

  static TextStyle bodyStyle(BuildContext context, {Color? color}) {
    final t = Theme.of(context).textTheme;
    final base = t.bodyMedium ?? t.bodyLarge ?? t.labelLarge ?? _fallbackBody();
    return base.copyWith(
          fontSize: body,
          color: color ?? textSecondary,
        );
  }

  static TextStyle captionStyle(BuildContext context, {Color? color}) {
    final t = Theme.of(context).textTheme;
    final base = t.bodySmall ?? t.labelSmall ?? _fallbackBody();
    return base.copyWith(
          fontSize: caption,
          color: color ?? textSecondary,
        );
  }
}

/// Wraps guard subtree with card/input/button defaults without changing resident theme.
class GuardThemeScope extends StatelessWidget {
  const GuardThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;

    final tuned = base.copyWith(
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: isDark ? GuardTokens.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
          side: BorderSide(
            color: isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: GuardTokens.primaryFilled(context),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: GuardTokens.secondaryOutlined(context),
      ),
    );

    return Theme(data: tuned, child: child);
  }
}
