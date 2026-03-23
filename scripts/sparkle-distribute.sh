#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPCAST_PATH="${APPCAST_PATH:-$ROOT_DIR/build/appcast.xml}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/Export/ChromeTabManager.zip}"

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "Missing SPARKLE_PRIVATE_KEY environment variable."
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Archive not found at: $ARCHIVE_PATH"
  exit 1
fi

echo "Generating Sparkle appcast..."
echo "Archive: $ARCHIVE_PATH"
echo "Appcast: $APPCAST_PATH"
echo "This script is a project scaffold; plug in your Sparkle tooling command here."
# Example:
# /path/to/generate_appcast --ed-key-file "$SPARKLE_PRIVATE_KEY" --output "$APPCAST_PATH" "$ROOT_DIR/build/Export"

echo "Sparkle distribution scaffold complete."
