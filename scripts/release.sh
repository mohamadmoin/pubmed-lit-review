#!/usr/bin/env bash
# Bump version across VERSION, Flutter pubspec, and OpenAPI metadata.
# Usage: ./scripts/release.sh [patch|minor|major]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"
PUBSPEC="$ROOT/frontend/pubspec.yaml"
SETTINGS="$ROOT/backend/litreview/settings.py"
CHANGELOG="$ROOT/CHANGELOG.md"

BUMP="${1:-patch}"
CURRENT="$(tr -d '[:space:]' < "$VERSION_FILE")"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *)
    echo "Usage: $0 [patch|minor|major]"
    exit 1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
BUILD_NUMBER=$((MAJOR * 1000000 + MINOR * 1000 + PATCH))
TODAY="$(date +%Y-%m-%d)"

echo "$NEW_VERSION" > "$VERSION_FILE"

if [[ "$OSTYPE" == darwin* ]]; then
  sed -i '' "s/^version: .*/version: ${NEW_VERSION}+${BUILD_NUMBER}/" "$PUBSPEC"
else
  sed -i "s/^version: .*/version: ${NEW_VERSION}+${BUILD_NUMBER}/" "$PUBSPEC"
fi

echo "Updated VERSION -> $NEW_VERSION"
echo "Updated frontend/pubspec.yaml -> ${NEW_VERSION}+${BUILD_NUMBER}"
echo
echo "Next steps:"
echo "  1. Update CHANGELOG.md under ## [$NEW_VERSION] - $TODAY"
echo "  2. git add VERSION frontend/pubspec.yaml CHANGELOG.md"
echo "  3. git commit -m \"Release v${NEW_VERSION}\""
echo "  4. git tag -a \"v${NEW_VERSION}\" -m \"Release v${NEW_VERSION}\""
echo "  5. git push && git push origin \"v${NEW_VERSION}\""
echo
echo "See docs/RELEASE.md for the full release checklist."
