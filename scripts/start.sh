#!/usr/bin/env bash
# One-command setup: build web UI, start Docker stack, open browser.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_URL="${LITREVIEW_APP_URL:-http://127.0.0.1:8002/}"
HEALTH_URL="${LITREVIEW_HEALTH_URL:-http://127.0.0.1:8002/api/docs/}"

echo "=== LitReview ==="
echo

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but was not found."
  echo "Install Docker Desktop: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed but not running. Start Docker Desktop, then run this script again."
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
  echo
  echo "IMPORTANT — edit .env before generating documents:"
  echo "  1. PUBMED_EMAIL=your.email@example.com   (required by NCBI)"
  echo "  2. NEO4J_PASSWORD=choose-a-strong-password"
  echo "  3. LLM settings — OpenAI key OR local LM Studio (see docs/GETTING_STARTED.md)"
  echo
  if [[ -t 0 ]]; then
    read -r -p "Press Enter to continue after editing .env (or Ctrl+C to exit)..." _
  fi
fi

if [[ ! -f backend/frontend_dist/index.html ]]; then
  echo "Building web app..."
  "$ROOT/scripts/build-web.sh"
fi

echo "Starting services..."
docker compose up -d --build

echo
echo "Waiting for LitReview to become ready..."
TRIES=0
until curl -sf "$HEALTH_URL" >/dev/null 2>&1; do
  TRIES=$((TRIES + 1))
  if [[ $TRIES -ge 60 ]]; then
    echo "Timed out waiting for the app. Check logs with: docker compose logs django"
    exit 1
  fi
  sleep 2
done

echo
echo "LitReview is running."
echo "  Web app:  $APP_URL"
echo "  API docs: ${APP_URL%/}/api/docs/"
echo

if command -v open >/dev/null 2>&1; then
  open "$APP_URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$APP_URL"
else
  echo "Open this URL in your browser: $APP_URL"
fi

echo
echo "To stop: docker compose down"
echo "After UI changes, rebuild with: ./scripts/build-web.sh"
