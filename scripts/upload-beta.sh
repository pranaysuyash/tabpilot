#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_PATH="${PKG_PATH:-$ROOT_DIR/build/Export/ChromeTabManager.pkg}"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "Missing APPLE_ID or APPLE_APP_PASSWORD environment variables."
  exit 1
fi

if [[ ! -f "$PKG_PATH" ]]; then
  echo "Package not found at: $PKG_PATH"
  exit 1
fi

echo "Uploading $PKG_PATH to TestFlight..."
xcrun altool --upload-app \
             -f "$PKG_PATH" \
             -t macOS \
             -u "${APPLE_ID}" \
             -p "${APPLE_APP_PASSWORD}"

echo "Upload complete."
