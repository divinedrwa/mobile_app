import 'package:flutter/material.dart';

/// GatePass+ G+ mark + wordmark for auth and splash screens.
///
/// Layout tuned for the current assets (`gp_logo.png` G+, `gp_wordmark.png` text).
class AuthBrandLogo extends StatelessWidget {
  const AuthBrandLogo({
    super.key,
    this.markWidth = 108,
    this.showWordmark = true,
    this.compact = false,
  });

  /// Width of the G+ mark (height follows [ _markAspectRatio ]).
  final double markWidth;

  final bool showWordmark;

  /// Tighter gaps for society-select and other dense headers.
  final bool compact;

  /// Measured from `gp_logo.png` content bounds (w ≈ 1.08 × h).
  static const double _markAspectRatio = 1.08;

  /// Wordmark art is wider than the mark; keeps visual alignment with the G+.
  static const double _wordmarkWidthFactor = 2.12;

  @override
  Widget build(BuildContext context) {
    final markHeight = markWidth / _markAspectRatio;
    final wordmarkWidth = markWidth * _wordmarkWidthFactor;
    final gap = compact ? 6.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/splash/gp_logo.png',
          width: markWidth,
          height: markHeight,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
        if (showWordmark) ...[
          SizedBox(height: gap),
          Image.asset(
            'assets/splash/gp_wordmark.png',
            width: wordmarkWidth,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ],
      ],
    );
  }
}
