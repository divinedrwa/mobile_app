import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// **Rule:** `Color(0x...)` (and `Color.fromARGB / Color.fromRGBO`) literals
/// are not allowed outside `lib/theme/`. Use the token system instead —
/// `context.brand`, `context.surface`, `context.text`, `context.state`.
///
/// Why: hard-coded hex literals defeat atomic re-skinning, dark-mode
/// support, and the future API-driven theme override.
class ForbidColorLiteralOutsideTheme extends DartLintRule {
  const ForbidColorLiteralOutsideTheme() : super(code: _code);

  static const _code = LintCode(
    name: 'gatepass_no_color_literal',
    problemMessage:
        "Don't use Color(0x…) outside lib/theme/. Use context.brand / "
        ".surface / .text / .state instead (see lib/theme/README.md).",
    correctionMessage:
        'Replace with a token, e.g. `color: context.brand.accent` or '
        '`color: context.state.approved.solid`.',
  );

  static const _allowedPathSegment = '/lib/theme/';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path;
    if (path.contains(_allowedPathSegment)) return; // exempt the theme folder
    if (path.contains('/test/')) return; // exempt tests

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Color') return;
      // `Colors.black` etc. are static getters, not InstanceCreation, so
      // they don't reach this branch. Only the literal `Color(0x…)` ctor
      // (and `Color.fromARGB / fromRGBO`) does.
      reporter.atNode(node, _code);
    });
  }
}
