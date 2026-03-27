#!/bin/bash
# TabPilot - Build, Sign, and Notarize Script
# 
# This script builds the app, creates a DMG, signs it with your developer certificate,
# and submits it to Apple for notarization.
#
# Prerequisites:
# 1. Apple Developer account with Developer ID certificate installed
# 2. App-specific password generated at appleid.apple.com
# 3. Environment variables set:
#    - APPLE_SIGNING_IDENTITY: Your Developer ID certificate name (e.g., "Developer ID Application: Your Name")
#    - APPLE_ID: Your Apple ID email
#    - APPLE_APP_PASSWORD: App-specific password for notarization
#
# Usage:
#   ./scripts/build-and-notarize.sh [-- dmg | app | zip]
#
# Options:
#   dmg   Create and notarize a DMG (default)
#   app   Notarize the .app bundle directly
#   zip   Notarize a zip archive

set -euo pipefail

cd "$(dirname "$0")/.."

# Configuration
APP_NAME="TabPilot"
APP_BUNDLE_ID="com.pranay.tabpilot"
PRODUCT_BINARY="ChromeTabManager"
BUILD_DIR=".build/release"
DMG_NAME="${APP_NAME}-$(date +%Y%m%d)-unsigned.dmg"
DMG_FINAL="${APP_NAME}-$(date +%Y%m%d).dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    echo "TabPilot Build & Notarize Script"
    echo "================================"
    echo ""
    echo "Usage: $0 [mode]"
    echo ""
    echo "Modes:"
    echo "  dmg   Create and notarize a DMG (default)"
    echo "  app   Notarize the .app bundle directly"
    echo "  zip   Notarize a zip archive"
    echo ""
    echo "Environment Variables Required:"
    echo "  APPLE_SIGNING_IDENTITY    Your Developer ID certificate name"
    echo "  APPLE_ID                  Your Apple ID email"
    echo "  APPLE_APP_PASSWORD        App-specific password for notarization"
    echo ""
}

# Parse arguments
MODE="${1:-dmg}"

# Check for required environment variables
check_env_vars() {
    local missing=0
    
    if [[ -z "${APPLE_SIGNING_IDENTITY:-}" ]]; then
        log_error "APPLE_SIGNING_IDENTITY is not set"
        missing=1
    fi
    
    if [[ -z "${APPLE_ID:-}" ]]; then
        log_error "APPLE_ID is not set"
        missing=1
    fi
    
    if [[ -z "${APPLE_APP_PASSWORD:-}" ]]; then
        log_error "APPLE_APP_PASSWORD is not set"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        log_error "Missing required environment variables. See usage for details."
        exit 1
    fi
}

# Clean previous builds
clean() {
    log_info "Cleaning previous builds..."
    rm -rf "${BUILD_DIR}"
    rm -f "${DMG_NAME}" "${DMG_FINAL}"
    rm -rf "${APP_NAME}.app"
}

# Build the app
build() {
    log_info "Building release..."
    if ! swift build -c release 2>&1; then
        log_error "Build failed!"
        exit 1
    fi
    
    if [[ ! -f "${BUILD_DIR}/${PRODUCT_BINARY}" ]]; then
        log_error "Binary not found at ${BUILD_DIR}/${PRODUCT_BINARY}"
        exit 1
    fi
    
    log_info "Build successful!"
}

# Create app bundle
create_app_bundle() {
    log_info "Creating app bundle..."
    
    mkdir -p "${APP_NAME}.app/Contents/MacOS"
    mkdir -p "${APP_NAME}.app/Contents/Resources"
    
    # Create Info.plist
    cat > "${APP_NAME}.app/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ChromeTabManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.pranay.tabpilot</string>
    <key>CFBundleName</key>
    <string>TabPilot</string>
    <key>CFBundleDisplayName</key>
    <string>TabPilot</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 TabPilot. All rights reserved.</string>
</dict>
</plist>
PLIST
    
    # Copy binary
    cp -f "${BUILD_DIR}/${PRODUCT_BINARY}" "${APP_NAME}.app/Contents/MacOS/"
    
    # Copy entitlements if exists
    if [[ -f "ChromeTabManager.entitlements" ]]; then
        cp -f "ChromeTabManager.entitlements" "${APP_NAME}.app/Contents/Resources/"
    fi
    
    log_info "App bundle created at ${APP_NAME}.app"
}

# Sign the app
sign_app() {
    log_info "Signing app bundle..."
    
    # Sign the main binary
    codesign --force --deep --sign "${APPLE_SIGNING_IDENTITY}" \
        "${APP_NAME}.app/Contents/MacOS/${PRODUCT_BINARY}"
    
    # Sign the app bundle
    codesign --force --deep --sign "${APPLE_SIGNING_IDENTITY}" "${APP_NAME}.app"
    
    # Verify signature
    codesign --verify --verbose "${APP_NAME}.app" || {
        log_error "Code signature verification failed!"
        exit 1
    }
    
    log_info "App signed successfully!"
}

# Create DMG
create_dmg() {
    log_info "Creating DMG..."
    
    # Create a temporary directory for DMG contents
    local dmg_temp=$(mktemp -d)
    cp -R "${APP_NAME}.app" "${dmg_temp}/"
    
    # Copy background image if exists
    if [[ -f "scripts/dmg-background.png" ]]; then
        mkdir -p "${dmg_temp}/.background"
        cp "scripts/dmg-background.png" "${dmg_temp}/.background/"
    fi
    
    # Create DMG
    hdiutil create -srcfolder "${dmg_temp}" -volname "${APP_NAME}" \
        -format UDZO -compressionLevel 9 "${DMG_NAME}" || {
        log_error "Failed to create DMG"
        rm -rf "${dmg_temp}"
        exit 1
    }
    
    rm -rf "${dmg_temp}"
    log_info "DMG created at ${DMG_NAME}"
}

# Sign DMG
sign_dmg() {
    log_info "Signing DMG..."
    codesign --force --sign "${APPLE_SIGNING_IDENTITY}" "${DMG_NAME}"
    log_info "DMG signed successfully!"
}

# Notarize with Apple
notarize() {
    local artifact="${1:-${DMG_NAME}}"
    log_info "Submitting ${artifact} for notarization..."
    
    # Submit to Apple
    xcrun notarytool submit "${artifact}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_PASSWORD}" \
        --team-id "$(echo "${APPLE_SIGNING_IDENTITY}" | grep -oP '(?<=Team ID: )\w+' || echo "")" \
        --wait || {
        log_error "Notarization submission failed!"
        exit 1
    }
    
    log_info "Notarization completed successfully!"
}

# Staple the notarization ticket
staple() {
    local artifact="${1:-${DMG_NAME}}"
    log_info "Stapling notarization ticket..."
    
    xcrun stapler staple "${artifact}" || {
        log_warn "Stapling failed. The app may need to be connected to the internet on first run."
    }
    
    log_info "Stapling completed!"
}

# Verify notarization
verify_notarization() {
    local artifact="${1:-${DMG_NAME}}"
    log_info "Verifying notarization..."
    
    xcrun notarytool info "${artifact}" --apple-id "${APPLE_ID}" --password "${APPLE_APP_PASSWORD}" || {
        log_error "Verification failed!"
        exit 1
    }
    
    log_info "Notarization verified successfully!"
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo " TabPilot Build & Notarize"
    echo "=========================================="
    echo ""
    
    check_env_vars
    
    case "${MODE}" in
        dmg)
            clean
            build
            create_app_bundle
            sign_app
            create_dmg
            sign_dmg
            notarize "${DMG_NAME}"
            staple "${DMG_NAME}"
            
            # Rename to final
            mv "${DMG_NAME}" "${DMG_FINAL}"
            log_info "Final DMG: ${DMG_FINAL}"
            ;;
        app)
            clean
            build
            create_app_bundle
            sign_app
            notarize "${APP_NAME}.app"
            staple "${APP_NAME}.app"
            ;;
        zip)
            clean
            build
            create_app_bundle
            sign_app
            
            log_info "Creating zip archive..."
            zip -r "${APP_NAME}.zip" "${APP_NAME}.app"
            notarize "${APP_NAME}.zip"
            staple "${APP_NAME}.zip"
            ;;
        *)
            log_error "Unknown mode: ${MODE}"
            usage
            exit 1
            ;;
    esac
    
    echo ""
    echo "=========================================="
    log_info "Build, sign, and notarize complete!"
    echo "=========================================="
    echo ""
}

main
