import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors_bridge.dart';

/// 🎨 GATEPASS+ - DESIGN TOKENS
/// Centralized design system — professional brand palette.
///
/// Brand colors from GatePass+ Play Store asset pack (teal-green + navy):
/// - Primary: Deep Teal (#004D40) — brand, buttons, headers
/// - Secondary: Teal (#00695C) — gradients, secondary actions
/// - Accent: Vibrant Green (#00C853) — success, approve, highlights
///
/// This file contains all design tokens used throughout the app:
/// - Colors (Brand Green, Navy, Semantic, Neutral)
/// - Typography (Headings, Body, Labels, Captions)
/// - Spacing (Based on 8pt grid)
/// - Radius (Border radius values)
/// - Elevation (Shadow levels)
/// - Components (Input fields, buttons, etc.)

// ============================================================================
// COLORS - Design Tokens (GatePass+ Brand)
// ============================================================================

/// Design tokens — resolves live from [AppColorBridge] so every screen that
/// imports `DesignColors.*` reflects the society's admin-configured theme the
/// moment it loads. Values mirror [AppColors]; for new code prefer
/// `context.brand` / `context.surface` or [AppColors].
///
/// NOTE: these are getters (not `const`) on purpose — they must re-read the
/// active palette on every build. Do not reintroduce `const` here.
class DesignColors {
  DesignColors._();

  static AppColorState get _c => AppColorBridge.current;

  // ── PRIMARY — Brand ────────────────────────────────────────────────────────
  static Color get primary      => _c.primary;
  static Color get primaryLight => _c.primaryLight;
  static Color get primaryDark  => _c.primaryDark;

  // ── SECONDARY ──────────────────────────────────────────────────────────────
  static Color get secondary => _c.secondary;

  // ── ACCENT ─────────────────────────────────────────────────────────────────
  static Color get accent      => _c.accent;
  static Color get accentHover => _c.accentContainer;

  // ── SURFACES ──────────────────────────────────────────────────────────────
  static Color get background  => _c.background;
  static Color get surface     => _c.surface;
  static Color get surfaceSoft => _c.surfaceVariant;

  // ── TEXT ──────────────────────────────────────────────────────────────────
  static Color get textPrimary   => _c.textPrimary;
  static Color get textSecondary => _c.textSecondary;
  static Color get textTertiary  => _c.textTertiary;

  // ── BORDERS ───────────────────────────────────────────────────────────────
  static Color get borderLight => _c.border;
  static Color get border      => _c.borderDark;
  static Color get divider     => _c.divider;

  // ── SEMANTIC ──────────────────────────────────────────────────────────────
  static Color get success      => _c.success;
  static Color get successLight => _c.successLight;
  static Color get warning      => _c.warning;
  static Color get error        => _c.error;
  static Color get errorLight   => _c.errorLight;
  static Color get info         => _c.info;

  // ── SOCIAL (brand-fixed, never themed) ─────────────────────────────────────
  static const Color google = Color(0xFFDB4437);
  static const Color apple  = Color(0xFF000000);

  // ── OVERLAYS (derived from active brand) ───────────────────────────────────
  static Color get hoverOverlay    => _c.primary.withValues(alpha: 0.05);
  static Color get pressedOverlay  => _c.primary.withValues(alpha: 0.10);
  static Color get focusOverlay    => _c.primary.withValues(alpha: 0.12);
  static const Color disabledOverlay = Color(0x61FFFFFF);

  // ── GRADIENTS (derived from active brand) ──────────────────────────────────
  static LinearGradient get primaryGradient => _c.primaryGradient;

  static LinearGradient get secondaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_c.secondary, _c.accent],
      );

  static LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_c.accent, _c.accentContainer],
      );

  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_c.background, _c.surface],
      );

  // ── TERTIARY (legacy alias) ────────────────────────────────────────────────
  static Color get tertiary => _c.textSecondary;
}

// ============================================================================
// TYPOGRAPHY - Design Tokens
// ============================================================================

class DesignTypography {
  DesignTypography._();

  /// Inter family name registered by Google Fonts (same metrics on iOS and Android).
  static String get fontFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  /// Heading XL - 28/Bold/36 (Size/Weight/Line Height)
  static TextStyle get headingXL => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        letterSpacing: -0.5,
        color: DesignColors.textPrimary,
      );

  /// Heading L - 22/Semibold/30 (for section titles)
  static TextStyle get headingL => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 30 / 22,
        letterSpacing: -0.3,
        color: DesignColors.textPrimary,
      );

  /// Heading M - 18/Semibold/24 (for card headers)
  static TextStyle get headingM => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        letterSpacing: -0.2,
        color: DesignColors.textPrimary,
      );

  /// Body - 16/Regular/24 (main content)
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0,
        color: DesignColors.textPrimary,
      );

  /// Body Medium - 16/Medium/24 (emphasized content)
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        letterSpacing: 0,
        color: DesignColors.textPrimary,
      );

  /// Body Small - 14/Regular/20 (secondary content)
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0,
        color: DesignColors.textSecondary,
      );

  /// Label - 14/Medium/20 (form labels, buttons)
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: DesignColors.textPrimary,
      );

  /// Label Small - 12/Medium/16 (small labels, tags)
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.2,
        color: DesignColors.textSecondary,
      );

  /// Caption - 12/Regular/16 (helper text, timestamps)
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        letterSpacing: 0.1,
        color: DesignColors.textTertiary,
      );

  /// Caption Small - 10/Regular/14 (very small text)
  static TextStyle get captionSmall => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 14 / 10,
        letterSpacing: 0.1,
        color: DesignColors.textTertiary,
      );

  /// Button text style - 16/Medium
  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.0,
        letterSpacing: 0.2,
      );

  /// Button Small text style - 14/Medium
  static TextStyle get buttonSmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.0,
        letterSpacing: 0.2,
      );
}

// ============================================================================
// SPACING - Design Tokens (8pt Grid System)
// ============================================================================

class DesignSpacing {
  // BASE UNIT - 8pt grid
  static const double base = 8.0;
  
  // SPACING SCALE
  static const double xs = base * 0.5;   // 4px
  static const double sm = base;         // 8px
  static const double md = base * 1.5;   // 12px
  static const double lg = base * 2;     // 16px
  static const double xl = base * 3;     // 24px
  static const double xxl = base * 4;    // 32px
  static const double xxxl = base * 6;   // 48px
  
  // COMPONENT SPECIFIC
  /// Top padding for screens (considers safe area)
  static const double screenTopPadding = xxl; // 32px
  
  /// Standard screen horizontal padding
  static const double screenPaddingH = lg; // 16px
  
  /// Standard screen vertical padding
  static const double screenPaddingV = lg; // 16px
  
  /// Card content padding
  static const double cardPadding = lg; // 16px
  
  /// List item padding vertical
  static const double listItemPaddingV = md; // 12px
  
  /// List item padding horizontal
  static const double listItemPaddingH = lg; // 16px
  
  /// Button padding vertical
  static const double buttonPaddingV = md; // 12px
  
  /// Button padding horizontal
  static const double buttonPaddingH = xl; // 24px
  
  /// Input field padding vertical
  static const double inputPaddingV = md; // 12px
  
  /// Input field padding horizontal
  static const double inputPaddingH = lg; // 16px
  
  // GAPS (for Flex layouts)
  static const double gapXS = xs;   // 4px
  static const double gapSM = sm;   // 8px
  static const double gapMD = md;   // 12px
  static const double gapLG = lg;   // 16px
  static const double gapXL = xl;   // 24px
}

// ============================================================================
// RADIUS - Design Tokens
// ============================================================================

class DesignRadius {
  /// Extra small radius - 4dp
  static const double xs = 4.0;
  
  /// Small radius - 6dp
  static const double sm = 6.0;
  
  /// Medium radius - 8dp (standard for inputs, buttons)
  static const double md = 8.0;
  
  /// Large radius - 12dp (standard for cards)
  static const double lg = 12.0;
  
  /// Extra large radius - 16dp (for large cards, modals)
  static const double xl = 16.0;
  
  /// XX Large radius - 24dp (for hero sections)
  static const double xxl = 24.0;
  
  /// Full radius - Creates circular shape
  static const double full = 9999.0;
  
  // COMMON BORDER RADIUS
  static BorderRadius get borderXS => BorderRadius.circular(xs);
  static BorderRadius get borderSM => BorderRadius.circular(sm);
  static BorderRadius get borderMD => BorderRadius.circular(md);
  static BorderRadius get borderLG => BorderRadius.circular(lg);
  static BorderRadius get borderXL => BorderRadius.circular(xl);
  static BorderRadius get borderXXL => BorderRadius.circular(xxl);
  static BorderRadius get borderFull => BorderRadius.circular(full);
}

// ============================================================================
// ELEVATION - Design Tokens (Shadow)
// ============================================================================

class DesignElevation {
  /// No elevation
  static const List<BoxShadow> none = [];
  
  /// Subtle elevation - y=4 (for hover states)
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0D000000), // 5% black
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  /// Medium elevation - y=8 (for cards)
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A000000), // 10% black
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
  
  /// High elevation - y=12 (for modals, dropdowns)
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1F000000), // 12% black
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];
  
  /// Very high elevation - y=16 (for floating elements)
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x26000000), // 15% black
      offset: Offset(0, 16),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];
  
  /// Multi-layer shadow (for premium look)
  static const List<BoxShadow> premium = [
    BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];
}

// ============================================================================
// COMPONENT TOKENS - Pre-defined component styles
// ============================================================================

class DesignComponents {
  // INPUT FIELD DECORATION
  static InputDecoration inputDecoration({
    String? label,
    String? hint,
    String? error,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabled: enabled,
      filled: true,
      fillColor: enabled ? DesignColors.surface : DesignColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.inputPaddingH,
        vertical: DesignSpacing.inputPaddingV,
      ),
      // Default border
      border: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: BorderSide(
          color: DesignColors.borderLight,
          width: 1,
        ),
      ),
      // Enabled border
      enabledBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: BorderSide(
          color: DesignColors.borderLight,
          width: 1,
        ),
      ),
      // Focused border
      focusedBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: BorderSide(
          color: DesignColors.primary,
          width: 2,
        ),
      ),
      // Error border
      errorBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: BorderSide(
          color: DesignColors.error,
          width: 1,
        ),
      ),
      // Focused error border
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: BorderSide(
          color: DesignColors.error,
          width: 2,
        ),
      ),
      // Disabled border
      disabledBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: BorderSide(
          color: DesignColors.borderLight,
          width: 1,
        ),
      ),
      // Text styles
      labelStyle: DesignTypography.label.copyWith(
        color: enabled ? DesignColors.textSecondary : DesignColors.textTertiary,
      ),
      hintStyle: DesignTypography.body.copyWith(
        color: DesignColors.textTertiary,
      ),
      errorStyle: DesignTypography.caption.copyWith(
        color: DesignColors.error,
      ),
    );
  }
  
  // CARD DECORATION
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double? borderWidth,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? DesignColors.surface,
      borderRadius: DesignRadius.borderLG,
      border: Border.all(
        color: borderColor ?? DesignColors.borderLight,
        width: borderWidth ?? 1,
      ),
      boxShadow: boxShadow ?? DesignElevation.sm,
    );
  }
  
  // BUTTON STYLE - Primary
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: DesignColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.buttonPaddingH,
      vertical: DesignSpacing.buttonPaddingV,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderMD,
    ),
    textStyle: DesignTypography.button,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return DesignColors.pressedOverlay;
      }
      if (states.contains(WidgetState.hovered)) {
        return DesignColors.hoverOverlay;
      }
      return null;
    }),
  );
  
  // BUTTON STYLE - Secondary
  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: DesignColors.primary,
    backgroundColor: Colors.transparent,
    side: BorderSide(
      color: DesignColors.primary,
      width: 1,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.buttonPaddingH,
      vertical: DesignSpacing.buttonPaddingV,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderMD,
    ),
    textStyle: DesignTypography.button,
  );
  
  // BUTTON STYLE - Disabled
  static ButtonStyle get disabledButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: DesignColors.surfaceSoft,
    foregroundColor: DesignColors.textTertiary,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.buttonPaddingH,
      vertical: DesignSpacing.buttonPaddingV,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderMD,
    ),
    textStyle: DesignTypography.button,
  );
  
  // SOCIAL BUTTON - Google
  static ButtonStyle get googleButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: DesignColors.textPrimary,
    backgroundColor: Colors.white,
    side: BorderSide(
      color: DesignColors.borderLight,
      width: 1,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.buttonPaddingH,
      vertical: DesignSpacing.buttonPaddingV,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderMD,
    ),
    textStyle: DesignTypography.button,
  );
  
  // SOCIAL BUTTON - Apple
  static ButtonStyle get appleButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: DesignColors.apple,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.buttonPaddingH,
      vertical: DesignSpacing.buttonPaddingV,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderMD,
    ),
    textStyle: DesignTypography.button,
  );
}

// ============================================================================
// DESIGN SYSTEM USAGE EXAMPLES
// ============================================================================

/// Example usage:
/// 
/// ```dart
/// // Colors
/// Container(
///   color: DesignColors.surface,
///   child: Text(
///     'Hello World',
///     style: DesignTypography.headingXL,
///   ),
/// );
/// 
/// // Spacing
/// Padding(
///   padding: EdgeInsets.all(DesignSpacing.lg),
///   child: Column(
///     gap: DesignSpacing.gapMD,
///     children: [...],
///   ),
/// );
/// 
/// // Input Field
/// TextField(
///   decoration: DesignComponents.inputDecoration(
///     label: 'Email',
///     hint: 'Enter your email',
///     prefixIcon: Icon(Icons.email),
///   ),
/// );
/// 
/// // Button
/// ElevatedButton(
///   style: DesignComponents.primaryButtonStyle,
///   onPressed: () {},
///   child: Text('Sign In'),
/// );
/// 
/// // Card
/// Container(
///   decoration: DesignComponents.cardDecoration(),
///   padding: EdgeInsets.all(DesignSpacing.cardPadding),
///   child: Text('Card content'),
/// );
/// ```
