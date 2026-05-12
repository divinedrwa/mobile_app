import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/forbid_color_literal.dart';

/// Entry point that the `custom_lint` analyzer plugin loads.
/// Hooked up via the host project's `analysis_options.yaml`:
///
/// ```yaml
/// analyzer:
///   plugins:
///     - custom_lint
/// ```
PluginBase createPlugin() => _GatePassLintsPlugin();

class _GatePassLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const ForbidColorLiteralOutsideTheme(),
      ];
}
