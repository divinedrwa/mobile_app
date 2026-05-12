#!/usr/bin/env bash
# Forbid `Color(0xFF…)` hex literals outside `lib/theme/`.
#
# Modes:
#   * (default)     report-only — prints offenders, exits 0
#   * --strict      report + fail with exit 1 (use after legacy migration)
#
# Pass `--strict` in CI once `lib/core/theme/` and feature widgets have
# migrated to `context.brand` / `context.state` / etc.

set -euo pipefail

cd "$(dirname "$0")/.."

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

OFFENDERS=$(grep -RnE 'Color\(0x[0-9A-Fa-f]{6,8}\)' lib \
  --include='*.dart' \
  | grep -v '^lib/theme/' \
  || true)

if [[ -z "$OFFENDERS" ]]; then
  echo "✓ No hard-coded Color(0x...) literals outside lib/theme/."
  exit 0
fi

COUNT=$(printf '%s\n' "$OFFENDERS" | wc -l | tr -d ' ')

if [[ $STRICT -eq 1 ]]; then
  echo "✗ $COUNT hard-coded Color(0x...) literals found outside lib/theme/:"
  echo
  echo "$OFFENDERS"
  echo
  echo "Use context.brand / context.surface / context.text / context.state /"
  echo "context.spacing / context.radius (see lib/theme/context_extensions.dart)."
  exit 1
fi

echo "⚠ $COUNT hard-coded Color(0x...) usage(s) outside lib/theme/ — legacy code, migration pending."
echo "  Run with --strict in CI once migration is complete."
exit 0
