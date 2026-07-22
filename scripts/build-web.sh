#!/usr/bin/env bash
# Build the Flutter web app into backend/frontend_dist for local Django serving.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND="$ROOT/frontend"
OUTPUT="$ROOT/backend/frontend_dist"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found."
  echo "Install Flutter (https://docs.flutter.dev/get-started/install) and ensure"
  echo "  flutter  is on your PATH, then run this script again."
  exit 1
fi

cd "$FRONTEND"
if ! flutter pub get; then
  echo
  echo "flutter pub get failed."
  echo "If you see 'authorization failed', pub.dev is likely blocked or unreachable from your network."
  echo "Try:"
  echo "  1. Toggle VPN (on if blocked region, off if VPN interferes)"
  echo "  2. cd frontend && flutter pub get -v   (shows which package fails)"
  echo "  3. dart pub token list                 (remove stale tokens if any)"
  echo "See docs/GETTING_STARTED.md#pubdev-access"
  exit 1
fi
flutter build web --release --dart-define=API_BASE_URL=/api

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
cp -R build/web/. "$OUTPUT/"

echo "Web app built to backend/frontend_dist/"
echo "Start the stack with ./scripts/start.sh or docker compose up -d --build"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'litreview-django'; then
    echo "Refreshing Django container so it picks up the new web build..."
    docker compose -f "$ROOT/docker-compose.yml" up -d --force-recreate django
  fi
fi
