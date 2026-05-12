/// Raw spacing scale used by the GatePass+ theme system.
///
/// These constants are exposed via the [AppSpacing] `ThemeExtension`
/// (see `theme_extensions.dart`) and the `context.spacing` getter
/// (see `context_extensions.dart`). Widgets should prefer the context
/// getter; importing these directly is allowed only inside `lib/theme/`.
class AppSpacingTokens {
  AppSpacingTokens._();

  /// 4 — hair-line gaps inside compact controls.
  static const double s4 = 4;

  /// 8 — tight padding inside chips, badges.
  static const double s8 = 8;

  /// 12 — default padding inside list-item rows.
  static const double s12 = 12;

  /// 16 — default card padding.
  static const double s16 = 16;

  /// 24 — section gap inside a screen.
  static const double s24 = 24;

  /// 32 — gap between two top-level sections.
  static const double s32 = 32;

  /// 48 — page-level vertical breathing room.
  static const double s48 = 48;

  /// 64 — hero / empty-state vertical spacing.
  static const double s64 = 64;
}

/// Border-radius scale used by the GatePass+ theme system.
///
/// Exposed via the [AppRadius] `ThemeExtension`.
class AppRadiusTokens {
  AppRadiusTokens._();

  /// 6 — chips, badges, small pills.
  static const double sm = 6;

  /// 10 — buttons, input fields.
  static const double md = 10;

  /// 16 — cards, dialogs.
  static const double lg = 16;

  /// 9999 — fully rounded (avatars, FAB).
  static const double full = 9999;
}
