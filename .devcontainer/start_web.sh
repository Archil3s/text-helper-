#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

PORT="${PORT:-3000}"
LOG_FILE="/tmp/flutter-web.log"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed in this Codespace. Rebuild the container first."
  echo "Use: Command Palette > Codespaces: Rebuild Container"
  exit 1
fi

if [ ! -f "pubspec.yaml" ]; then
  echo "No Flutter project found. Creating a starter Flutter app in this repo..."
  flutter create .
fi

echo "Installing dependencies..."
flutter pub get

if pgrep -f "flutter run -d web-server.*--web-port ${PORT}" >/dev/null 2>&1; then
  echo "Flutter web server is already running on port ${PORT}."
else
  echo "Starting Flutter web server on port ${PORT}..."
  nohup flutter run -d web-server --web-hostname 0.0.0.0 --web-port "${PORT}" > "${LOG_FILE}" 2>&1 &
fi

echo "Preview port: ${PORT}"
echo "Logs: ${LOG_FILE}"
echo "To watch logs, run: tail -f ${LOG_FILE}"
