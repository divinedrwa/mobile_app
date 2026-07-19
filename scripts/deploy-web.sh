#!/usr/bin/env bash
set -euo pipefail

# Build and deploy the Flutter web app to Firebase Hosting (society-e1a2e).
#
# Usage:
#   bash scripts/deploy-web.sh              # production → https://society-e1a2e.web.app
#   bash scripts/deploy-web.sh --preview    # 7-day preview channel
#
# Requires: flutter, firebase CLI, android/key.properties not needed for web.

cd "$(dirname "$0")/.."

PROD_API="${API_BASE_URL:-https://gatepass-v037.onrender.com/api}"
LEGAL_BASE="${LEGAL_BASE_URL:-https://divinedrwa.github.io/GatePass-Legal}"

echo "==> Building Flutter web (release)…"
echo "    API_BASE_URL=$PROD_API"

flutter build web --release \
  --dart-define=API_BASE_URL="$PROD_API" \
  --dart-define=PRIVACY_POLICY_URL="$LEGAL_BASE/privacy_policy.html" \
  --dart-define=TERMS_CONDITIONS_URL="$LEGAL_BASE/terms_condition.html" \
  --dart-define=ACCOUNT_DELETION_URL="$LEGAL_BASE/account_deletion.html" \
  --dart-define=SUPPORT_EMAIL=divine.drwa@gmail.com

if [[ "${1:-}" == "--preview" ]]; then
  echo "==> Deploying to Firebase Hosting preview channel…"
  firebase hosting:channel:deploy preview --expires 7d
else
  echo "==> Deploying to Firebase Hosting (production)…"
  firebase deploy --only hosting --project society-e1a2e
fi

echo "==> Done. Live: https://society-e1a2e.web.app"
