#!/usr/bin/env bash
# Forbid `Color(0xFF…)` hex literals outside token registries.
#
# Allowed hex locations:
#   lib/theme/           — canonical AppColorPalette
#   lib/core/theme/      — bridge, chart_palette, semantic helpers
#
# Modes:
#   * (default)     report-only — prints offenders, exits 0
#   * --strict      fail with exit 1 (CI gate for lib/features/)

set -euo pipefail

cd "$(dirname "$0")/.."

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

OFFENDERS=$(grep -RnE 'Color\(0x[0-9A-Fa-f]{6,8}\)' lib \
  --include='*.dart' \
  | grep -v '^lib/theme/' \
  | grep -v '^lib/core/theme/' \
  || true)

if [[ -z "$OFFENDERS" ]]; then
  echo "✓ No hard-coded Color(0x...) literals outside token registries."
  exit 0
fi

COUNT=$(printf '%s\n' "$OFFENDERS" | wc -l | tr -d ' ')
FEATURE_COUNT=$(printf '%s\n' "$OFFENDERS" | grep -c '^lib/features/' || true)

echo "⚠ $COUNT hard-coded Color(0x...) usage(s) outside token registries."
echo "  lib/features/: $FEATURE_COUNT (target: migrate to DesignColors / semantic_colors / chart_palette)"

if [[ $STRICT -eq 1 ]]; then
  # Strict mode: only fail when lib/features still has literals (allows chart data in features to be zero over time).
  if [[ "$FEATURE_COUNT" -gt 0 ]]; then
    echo
    echo "✗ lib/features still contains $FEATURE_COUNT Color(0x...) literal(s):"
    printf '%s\n' "$OFFENDERS" | grep '^lib/features/' | head -40
    if [[ "$FEATURE_COUNT" -gt 40 ]]; then
      echo "  … and $((FEATURE_COUNT - 40)) more"
    fi
    echo
    echo "Use DesignColors / ActionColors / DueStatePalette / PaymentStatusColors / ChartPalette."
    exit 1
  fi
fi

exit 0
