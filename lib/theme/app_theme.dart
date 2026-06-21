import 'package:flutter/material.dart';

import '../core/theme/page_transitions.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'theme_extensions.dart';

/// Builds the GatePass+ [ThemeData] for a given [AppColorPalette].
///
/// **Future API-driven theming:** the only inputs are a palette and a
/// brightness. Once you have a `themeTokensProvider` that loads from your
/// API, swap [AppColorPalette.light] / [AppColorPalette.dark] for the
/// runtime values and rebuild `MaterialApp` — every screen reflects the
/// change because they read tokens via `context.brand`, `context.surface`,
/// `context.text`, `context.state`, `context.spacing`, `context.radius`.
class AppTheme {
  AppTheme._();

  static ThemeData light({AppColorPalette palette = AppColorPalette.light}) =>
      _build(palette: palette, brightness: Brightness.light);

  static ThemeData dark({AppColorPalette palette = AppColorPalette.dark}) =>
      _build(palette: palette, brightness: Brightness.dark);

  static ThemeData _build({
    required AppColorPalette palette,
    required Brightness brightness,
  }) {
    final brand = BrandColors.fromPalette(palette);
    final surface = SurfaceColors.fromPalette(palette);
    final text = TextColors.fromPalette(palette);
    final state = StateColors.fromPalette(palette);
    const spacing = AppSpacing();
    const radius = AppRadius();

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: brand.primary,
      onPrimary: text.inverse,
      primaryContainer: surface.elevated,
      onPrimaryContainer: text.primary,
      secondary: brand.accent,
      onSecondary: text.inverse,
      secondaryContainer: state.approved.bg,
      onSecondaryContainer: state.approved.fg,
      tertiary: state.info.solid,
      onTertiary: text.inverse,
      error: brand.danger,
      onError: text.inverse,
      errorContainer: state.denied.bg,
      onErrorContainer: state.denied.fg,
      surface: surface.defaultSurface,
      onSurface: text.primary,
      surfaceContainerLowest: surface.background,
      surfaceContainerLow: surface.defaultSurface,
      surfaceContainer: surface.elevated,
      surfaceContainerHigh: surface.elevated,
      surfaceContainerHighest: surface.elevated,
      onSurfaceVariant: text.secondary,
      outline: surface.border,
      outlineVariant: surface.border,
      shadow: const Color(0x14000000),
      scrim: const Color(0x66000000),
      inverseSurface: brightness == Brightness.light
          ? AppColorPalette.dark.surfaceDefault
          : AppColorPalette.light.surfaceDefault,
      onInverseSurface: text.inverse,
      inversePrimary: brand.accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // App-wide slide-up + fade route transitions (Cupertino on iOS/macOS to
      // keep swipe-back). See page_transitions.dart.
      pageTransitionsTheme: appPageTransitionsTheme,
      scaffoldBackgroundColor: surface.background,
      canvasColor: surface.defaultSurface,
      dividerColor: surface.border,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(text.primary),
      extensions: <ThemeExtension<dynamic>>[
        brand,
        surface,
        text,
        state,
        spacing,
        radius,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: surface.defaultSurface,
        foregroundColor: text.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.textTheme(text.primary).titleLarge,
        iconTheme: IconThemeData(color: text.secondary),
        actionsIconTheme: IconThemeData(color: text.secondary),
      ),
      cardTheme: CardThemeData(
        color: surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.lg),
          side: BorderSide(color: surface.border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: text.inverse,
          textStyle: AppTypography.textTheme(text.inverse).labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s24,
            vertical: spacing.s12,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text.primary,
          side: BorderSide(color: surface.border),
          textStyle: AppTypography.textTheme(text.primary).labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s24,
            vertical: spacing.s12,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text.secondary,
          textStyle: AppTypography.textTheme(text.secondary).labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.defaultSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: surface.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: surface.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: brand.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: brand.danger),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.s16,
          vertical: spacing.s12,
        ),
        hintStyle: TextStyle(color: text.tertiary),
        labelStyle: TextStyle(color: text.secondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface.elevated,
        labelStyle: AppTypography.textTheme(text.primary).labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: surface.border,
        space: 1,
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: text.tertiary),
      listTileTheme: ListTileThemeData(
        iconColor: text.tertiary,
        textColor: text.primary,
        tileColor: surface.defaultSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? AppColorPalette.dark.surfaceDefault
            : AppColorPalette.light.surfaceDefault,
        contentTextStyle: TextStyle(color: text.inverse),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand.primary,
        foregroundColor: text.inverse,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.primary.withValues(alpha: 0.15),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface.defaultSurface,
        selectedItemColor: brand.primary,
        unselectedItemColor: text.tertiary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand.primary;
          return text.tertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brand.primary.withValues(alpha: 0.3);
          }
          return surface.border;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand.primary,
        linearTrackColor: surface.border,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.scrolledUnder)) {
            return true;
          }
          return null; // system default on mobile
        }),
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return 8;
          }
          return 4;
        }),
        radius: const Radius.circular(4),
        thumbColor: WidgetStateProperty.all(
          text.tertiary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
