import 'package:flutter/material.dart';

import 'theme_extensions.dart';

/// =========================================================================
///  BuildContext getters — the **only** way widgets should read theme tokens.
///
///  ```dart
///  Container(
///    color: context.brand.accent,
///    padding: EdgeInsets.all(context.spacing.s16),
///    decoration: BoxDecoration(
///      color: context.state.approved.bg,
///      borderRadius: BorderRadius.circular(context.radius.md),
///    ),
///    child: Text(
///      'Approved',
///      style: TextStyle(color: context.state.approved.fg),
///    ),
///  );
///  ```
///
///  Never use `Color(0xFF…)` outside `lib/theme/`. A CI grep check in
///  `scripts/check_hardcoded_colors.sh` will fail the build if you do.
/// =========================================================================
extension AppThemeContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
  SurfaceColors get surface => Theme.of(this).extension<SurfaceColors>()!;
  TextColors get text => Theme.of(this).extension<TextColors>()!;
  StateColors get state => Theme.of(this).extension<StateColors>()!;
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;
  AppRadius get radius => Theme.of(this).extension<AppRadius>()!;

  /// Returns `true` when the active [Theme] is dark.
  /// Useful for choosing an asset variant (e.g., dark-mode logo).
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
