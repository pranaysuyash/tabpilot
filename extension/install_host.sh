#!/bin/bash
# install_host.sh — Registers the TabTimeHost as a Chrome Native Messaging Host
# Run this after building/installing the app, or the app can run it on first launch.

set -euo pipefail

HOST_NAME="com.tabpilot.timetracker"
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
MANIFEST_TEMPLATE="$(dirname "$0")/com.tabpilot.timetracker.json"

# Determine the path to the built host executable
# If running from the project directory, use .build; if installed, use app bundle
if [ -f "$(dirname "$0")/../.build/release/TabTimeHost" ]; then
    HOST_PATH="$(cd "$(dirname "$0")/../.build/release" && pwd)/TabTimeHost"
elif [ -f "$(dirname "$0")/../.build/debug/TabTimeHost" ]; then
    HOST_PATH="$(cd "$(dirname "$0")/../.build/debug" && pwd)/TabTimeHost"
else
    HOST_PATH="/Applications/TabPilot.app/Contents/MacOS/TabTimeHost"
fi

mkdir -p "$CHROME_DIR"

# Generate manifest with correct path
cat > "$CHROME_DIR/$HOST_NAME.json" << EOF
{
  "name": "$HOST_NAME",
  "description": "TabPilot Tab Time Tracker Native Messaging Host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": []
}
EOF

echo "✅ Native messaging host installed: $CHROME_DIR/$HOST_NAME.json"
echo "   Host path: $HOST_PATH"
echo ""
echo "After loading the Chrome extension, add its ID to 'allowed_origins' in the manifest,"
echo "or remove 'allowed_origins' to allow all extensions."
