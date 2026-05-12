/// Public barrel for the GatePass+ theme system.
///
/// Import this single file from app shell code (and **only** that — feature
/// widgets should `import '../../theme/context_extensions.dart';` and use
/// the `context.brand` / `context.state` / `context.spacing` getters).
library;

export 'app_colors.dart' show AppColorPalette;
export 'app_spacing.dart' show AppSpacingTokens, AppRadiusTokens;
export 'app_theme.dart' show AppTheme;
export 'app_typography.dart' show AppTypography;
export 'context_extensions.dart';
export 'theme_controller.dart';
export 'theme_extensions.dart';
