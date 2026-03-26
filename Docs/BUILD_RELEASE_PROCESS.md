# Build and Release Process

## Overview
This document outlines the complete process for building, signing, notarizing, and releasing Chrome Tab Manager (TabPilot) for direct distribution.

## Prerequisites
1. Apple Developer ID certificate installed in Keychain
2. notarytool installed (part of Xcode command line tools)
3. Access to distribution server (S3/CloudFront or equivalent)
4. Sparkle private key for update signatures (kept offline)
5. Access to payment provider webhook endpoint (for testing)
6. Clean build environment (recommended: CI/CD pipeline)

## Directory Structure
```
/build-output/
  /archives/          # Old DMG versions
  /updates/           # Current DMG and appcast
  /logs/              # Build and notarization logs
  /tmp/               # Temporary build files
```

## Step-by-Step Process

### 1. Preparation
```bash
# Ensure we're on the correct branch
git checkout staging
git pull origin staging

# Update version number in Sources/ChromeTabManager/Version.swift
# Format: MAJOR.MINOR.PATCH (e.g., 1.2.3)

# Clean previous build artifacts
xcodebuild clean -scheme ChromeTabManager -configuration Release
rm -rf /build-output/tmp/*
```

### 2. Build and Sign
```bash
# Build the app
xcodebuild -scheme ChromeTabManager \
  -configuration Release \
  -derivedDataPath /build-output/tmp/build \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

# Locate the built app
APP_PATH="/build-output/tmp/build/Build/Products/Release/ChromeTabManager.app"

# Verify signing
codesign --verify --verbose=4 "$APP_PATH"
spctl --assess --type execute "$APP_PATH"
```

### 3. Create DMG
```bash
# Create temporary directory for DMG contents
mkdir -p /build-output/tmp/dmg
cp -R "$APP_PATH" /build-output/tmp/dmg/

# Create symlink to Applications folder
ln -s /Applications /build-output/tmp/dmg/Applications

# Create DMG with proper permissions
hdiutil create "/build-output/updates/TabPilot-${VERSION}.dmg" \
  -srcfolder "/build-output/tmp/dmg" \
  -volname "TabPilot" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDZO \
  -imagekey zlib-level=9

# Clean up temporary DMG contents
rm -rf /build-output/tmp/dmg
```

### 4. Notarize DMG
```bash
# Submit for notarization
xcrun notarytool submit "/build-output/updates/TabPilot-${VERSION}.dmg" \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Check notarization status (if not waiting)
# xcrur notarytool log <id> --keychain-profile "AC_PASSWORD"

# Staple notarization ticket to DMG
xcrun stapler staple "/build-output/updates/TabPilot-${VERSION}.dmg"

# Verify notarization
spctl -a -t exec -vvv "/build-output/updates/TabPilot-${VERSION}.dmg"
```

### 5. Generate Sparkle Update Items
```bash
# Generate SHA-256 checksum
shasum -a 256 "/build-output/updates/TabPilot-${VERSION}.dmg" > \
  "/build-output/updates/TabPilot-${VERSION}.dmg.sha256"

# Generate Sparkle update XML item (using sign_update.sh from Sparkle)
# This requires the private DSA key kept offline
/usr/local/bin/sign_update \
  "/build-output/updates/TabPilot-${VERSION}.dmg" \
  "/build-output/updates/TabPilot-${VERSION}.dmg.sha256" \
  "/path/to/dsa_priv.pem" >> "/build-output/updates/appcast.xml"

# Or manually create XML item:
# <item>
#   <title>Version ${VERSION} (${SHORT_VERSION})</title>
#   <sparkle:version>${SHORT_VERSION}</sparkle:version>
#   <sparkle:shortVersionString>${SHORT_VERSION}</sparkle:shortVersionString>
#   <sparkle:releaseNotesLink>
#     https://tabpilot.app/release-notes/${VERSION}.html
#   </sparkle:releaseNotesLink>
#   <pubDate>$(date -R)</pubDate>
#   <enclosure
#     url="https://updates.tabpilot.app/TabPilot-${VERSION}.dmg"
#     sparkle:version="${SHORT_VERSION}"
#     sparkle:shortVersionString="${SHORT_VERSION}"
#     sparkle:dsaSignature="${SIGNATURE}"
#     length="${FILESIZE}"
#     type="application/octet-stream"
#   />
# </item>
```

### 6. Publish to Distribution Server
```bash
# Sync to S3/CloudFront (example using AWS CLI)
aws s3 sync /build-output/updates/ s3://tabpilot-updates/ \
  --exclude "*" \
  --include "TabPilot-*.dmg" \
  --include "TabPilot-*.dmg.sha256" \
  --include "appcast.xml" \
  --delete

# Or using gsutil for Google Cloud Storage
# gsutil -m cp /build-output/updates/* gs://tabpilot-updates/

# Invalidate CloudFront cache if needed
# aws cloudfront create-invalidation --distribution-id E12345 --paths "/appcast.xml" "/TabPilot-*.dmg"
```

### 7. Post-Release Verification
```bash
# Test download and installation
curl -L https://updates.tabpilot.app/TabPilot-${VERSION}.dmg -o /tmp/test.dmg
hdiutil attach /tmp/test.dmg
cp -R /Volumes/TabPilot/ChromeTabManager.app /Applications/
hdiutil detach /Volumes/TabPilot

# Launch and verify
open -a "/Applications/ChromeTabManager.app"

# Verify update mechanism works
# (Should show "No updates available" or offer this version if testing downgrade prevention)
```

### 8. Archive Old Versions
```bash
# Move current version to archives after confirming new version stable
# (Typically wait 24-48 hours after release)
mv /build-output/updates/TabPilot-${PREV_VERSION}.dmg /build-output/archives/
mv /build-output/updates/TabPilot-${PREV_VERSION}.dmg.sha256 /build-output/archives/
# Keep appcast.xml current - it should reference all available versions
```

## Automation Recommendations
For teams planning regular releases, consider automating this process with:

### CI/CD Pipeline (Example GitHub Actions)
1. Trigger on push to `main` tag (v*.*.*)
2. Build, sign, and notarize in macOS runner
3. Generate Sparkle items
4. Publish to S3/CloudFront
5. Create GitHub release
6. Notify team via Slack/email
7. Archive previous version after validation period

### Required Secrets in CI
- `APPLE_CERTIFICATE`: Developer ID certificate (base64)
- `APPLE_CERTIFICATE_PASSWORD`: Certificate password
- `APPLE_ID`: Apple ID for notarytool
- `APPLE_ID_PASSWORD`: App-specific password for notarytool
- `SPARKLE_PRIVATE_KEY`: DSA private key for update signatures
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: For S3 deployment
- `DODO_WEBHOOK_SECRET`: For testing payment flow

## Troubleshooting

### Notarization Failures
1. Check notarization log: `xcrun notarytool log <id> --keychain-profile "AC_PASSWORD"`
2. Common issues:
   - Missing hardened runtime entitlements
   - Use of prohibited APIs
   - Invalid signature
   - Missing entitlement for required capability

### Sparkle Signature Issues
1. Verify public key matches private key used for signing
2. Ensure DSA key format is correct (PKCS#8 or OpenSSL traditional)
3. Check that signature is base64-encoded correctly in XML

### Installation Problems
1. Gatekeeper blocking: `spctl --assess --type execute /Applications/ChromeTabManager.app`
2. Missing dependencies: Check Console.app for launch errors
3. Sandbox issues: If sandboxed, ensure all required entitlements are present

## Rollback Procedure
1. If critical defect found:
   a. Immediately remove version from appcast (mark as yanked)
   b. Notify users via website/status page
   c. Support prepares guidance: "Download previous version from https://updates.tabpilot.app/archives/TabPilot-{prev}.dmg"
   d. Next release jumps version number (e.g., from 1.2.3 to 1.3.0 skipping 1.2.4)

## Estimated Time
- Manual process: 45-60 minutes per release
- Automated pipeline: 15-20 minutes (mostly waiting for notarization)
- Notarization typically takes 5-15 minutes but can vary