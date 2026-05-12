import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 GATEPASS+ - DESIGN TOKENS (Legacy)
/// Centralized design system — premium teal-and-gold palette.
///
/// This file contains all design tokens used throughout the app:
/// - Colors (Primary Teal, Amber Accent, Semantic, Neutral)
/// - Typography (Headings, Body, Labels, Captions)
/// - Spacing (Based on 8pt grid)
/// - Radius (Border radius values)
/// - Elevation (Shadow levels)
/// - Components (Input fields, buttons, etc.)

// ============================================================================
// COLORS - Design Tokens
// ============================================================================

class DesignColors {
  // PRIMARY COLORS
  /// Primary Teal - Main brand color (#0F766E)
  static const Color primary = Color(0xFF0F766E);

  /// Primary Teal Light (#14B8A6)
  static const Color primaryLight = Color(0xFF14B8A6);

  /// Primary Teal Dark - For pressed states (#115E59)
  static const Color primaryDark = Color(0xFF115E59);
  
  // SECONDARY COLORS  
  /// Secondary color (#475569)
  static const Color secondary = Color(0xFF475569);
  
  /// Tertiary/Alternative color (#94A3B8)
  static const Color tertiary = Color(0xFF94A3B8);
  
  // NEUTRAL / SURFACES
  /// Background - Main app background (#F9FAFC)
  static const Color background = Color(0xFFF9FAFC);
  
  /// Surface - Card/Panel background (#FFFFFF)
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Surface Soft - Subtle background (#F1F5F9)
  static const Color surfaceSoft = Color(0xFFF1F5F9);
  
  // TEXT COLORS
  /// Text Primary - Main text color (#0F172A)
  static const Color textPrimary = Color(0xFF0F172A);
  
  /// Text Secondary - Secondary text (#475569)
  static const Color textSecondary = Color(0xFF475569);
  
  /// Text Tertiary - Disabled/placeholder (#94A3B8)
  static const Color textTertiary = Color(0xFF94A3B8);
  
  // BORDER / DIVIDER
  /// Border Light - Subtle borders (#E2E8F0)
  static const Color borderLight = Color(0xFFE2E8F0);
  
  /// Border - Standard borders (#CBD5E1)
  static const Color border = Color(0xFFCBD5E1);
  
  /// Divider color (#F1F5F9)
  static const Color divider = Color(0xFFF1F5F9);
  
  // SEMANTIC COLORS
  /// Error/Danger color (#EF4444)
  static const Color error = Color(0xFFEF4444);
  
  /// Success color (#22C55E)
  static const Color success = Color(0xFF22C55E);
  
  /// Warning color (#F59E0B)
  static const Color warning = Color(0xFFF59E0B);
  
  /// Info color (uses primary teal)
  static const Color info = primary;
  
  // SOCIAL COLORS
  /// Google red (#DB4437)
  static const Color google = Color(0xFFDB4437);
  
  /// Apple black (#000000)
  static const Color apple = Color(0xFF000000);
  
  // STATE COLORS (Overlays)
  /// Hover overlay (5% black)
  static const Color hoverOverlay = Color(0x0D000000);
  
  /// Pressed overlay (10% black)
  static const Color pressedOverlay = Color(0x1A000000);
  
  /// Focus overlay (12% primary)
  static const Color focusOverlay = Color(0x1F0F766E);
  
  /// Disabled overlay (38% white)
  static const Color disabledOverlay = Color(0x61FFFFFF);
  
  // GRADIENTS
  /// Primary gradient for hero sections
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  /// Subtle background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFAFAFA), Color(0xFFFFFFFF)],
  );
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
        borderSide: const BorderSide(
          color: DesignColors.borderLight,
          width: 1,
        ),
      ),
      // Enabled border
      enabledBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: const BorderSide(
          color: DesignColors.borderLight,
          width: 1,
        ),
      ),
      // Focused border
      focusedBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: const BorderSide(
          color: DesignColors.primary,
          width: 2,
        ),
      ),
      // Error border
      errorBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: const BorderSide(
          color: DesignColors.error,
          width: 1,
        ),
      ),
      // Focused error border
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: const BorderSide(
          color: DesignColors.error,
          width: 2,
        ),
      ),
      // Disabled border
      disabledBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderMD,
        borderSide: const BorderSide(
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
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
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
  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: DesignColors.primary,
    backgroundColor: Colors.transparent,
    side: const BorderSide(
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
  static ButtonStyle disabledButtonStyle = ElevatedButton.styleFrom(
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
  static ButtonStyle googleButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: DesignColors.textPrimary,
    backgroundColor: Colors.white,
    side: const BorderSide(
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
  static ButtonStyle appleButtonStyle = ElevatedButton.styleFrom(
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
