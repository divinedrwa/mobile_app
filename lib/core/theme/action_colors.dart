import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Semantic action / tile colors — always read from the active society theme.
abstract final class ActionColors {
  static Color get brand => DesignColors.primary;
  static Color get secondary => DesignColors.secondary;
  static Color get accent => DesignColors.accent;
  static Color get success => DesignColors.success;
  static Color get warning => DesignColors.warning;
  static Color get danger => DesignColors.error;
  static Color get info => DesignColors.info;
  static Color get neutral => DesignColors.textTertiary;
}
