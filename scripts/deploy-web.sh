#!/usr/bin/env bash
set -euo pipefail

# Build and deploy the Flutter web app to Firebase Hosting.
# Usage: bash scripts/deploy-web.sh [--preview]
#   --preview  Deploy to a preview channel instead of production.

cd "$(dirname "$0")/.."

echo "==> Building Flutter web release..."
flutter build web --release

if [[ "${1:-}" == "--preview" ]]; then
  echo "==> Deploying to Firebase Hosting preview channel..."
  firebase hosting:channel:deploy preview --expires 7d
else
  echo "==> Deploying to Firebase Hosting (production)..."
  firebase deploy --only hosting
fi

echo "==> Done."
