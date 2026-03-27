#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

usage() {
    echo "TabPilot - Build & Launch"
    echo "==================================="
    echo ""
    echo "Usage: $0 [mode]"
    echo ""
    echo "Modes:"
    echo "  --bundle   Build, sync to app bundle, then launch app (default)"
    echo "  --binary   Build and launch binary directly from .build/release"
    echo "  --help     Show this help message"
    echo ""
}

MODE=""
if [[ $# -gt 0 ]]; then
    case "$1" in
        --bundle|-b)
            MODE="bundle"
            ;;
        --binary|-l)
            MODE="binary"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
else
    MODE="bundle"
fi

APP_NAME="TabPilot"
APP_PATH="$APP_NAME.app"
BUILD_BIN=".build/release/ChromeTabManager"

echo "Building release..."
if ! swift build -c release 2>&1; then
    echo "ERROR: Build failed!" >&2
    exit 1
fi

if [[ ! -f "$BUILD_BIN" ]]; then
    echo "ERROR: Binary not found at $BUILD_BIN" >&2
    exit 1
fi

BUILD_SIZE=$(stat -f %z "$BUILD_BIN" 2>/dev/null || stat -c %s "$BUILD_BIN" 2>/dev/null || echo "0")
echo "Built binary: $BUILD_SIZE bytes"

if [[ "$MODE" == "bundle" ]]; then
    echo "Updating app bundle..."
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"
    
    # Create minimal Info.plist if it doesn't exist
    if [[ ! -f "$APP_PATH/Contents/Info.plist" ]]; then
        cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ChromeTabManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.pranay.chrometabmanager</string>
    <key>CFBundleName</key>
    <string>TabPilot</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST
        echo "Created Info.plist"
    fi
    
    cp -f "$BUILD_BIN" "$APP_PATH/Contents/MacOS/"
    
    BUNDLE_BIN="$APP_PATH/Contents/MacOS/ChromeTabManager"
    if [[ ! -f "$BUNDLE_BIN" ]]; then
        echo "ERROR: Bundle binary not found after copy!" >&2
        exit 1
    fi
    
    BUNDLE_SIZE=$(stat -f %z "$BUNDLE_BIN" 2>/dev/null || stat -c %s "$BUNDLE_BIN" 2>/dev/null || echo "0")
    if [[ "$BUILD_SIZE" != "$BUNDLE_SIZE" ]]; then
        echo "ERROR: Bundle binary size mismatch! Build: $BUILD_SIZE, Bundle: $BUNDLE_SIZE" >&2
        exit 1
    fi
    
    codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true
    
    echo "Launching app bundle..."
    open "$APP_PATH"
    LAUNCH_TARGET="$APP_PATH"
else
    echo "Launching binary directly..."
    "$BUILD_BIN" &
    LAUNCH_TARGET="$BUILD_BIN"
fi

sleep 2

PID=$(pgrep -f "ChromeTabManager" | head -1 || echo "")

if [[ -n "$PID" ]]; then
    echo "Running (PID: $PID)"
    exit 0
else
    echo "WARNING: Process not found via pgrep, but launch may still succeed" >&2
    exit 0
fi
