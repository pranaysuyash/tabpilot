# Notarization Guide

## Overview
This document explains the notarization process for Chrome Tab Manager (TabPilot) to ensure compatibility with macOS Gatekeeper.

## Why Notarization Is Required
Starting with macOS Catalina (10.15), Apple requires all software distributed outside the Mac App Store to be notarized. Without notarization:
- Gatekeeper will block the application from launching
- Users will see "App can't be opened because it is from an unidentified developer"
- While users can bypass this via right-click → Open, it creates poor user experience and reduces trust

## Notarization vs Signing
- **Signing**: Applying your Developer ID signature to the app or DMG
  - Required first step
  - Proves you are the developer and the code hasn't been tampered with
- **Notarization**: Uploading signed software to Apple for automated security scanning
  - Second step after signing
  - Apple checks for known malware, security issues, and policy compliance
  - Returns a notarization ticket that you staple to your software

## Prerequisites
1. Apple Developer ID certificate installed in your keychain
2. Xcode command line tools installed (includes notarytool)
3. An app-specific password for your Apple ID (if using 2FA)
4. The signed application or DMG ready for notarization

## Step-by-Step Notarization Process

### 1. Sign Your Software
First, ensure your app or DMG is signed with your Developer ID:

```bash
# Sign the app bundle
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
  --options runtime \
  --timestamp \
  "/path/to/ChromeTabManager.app"

# Verify the signing
codesign --verify --verbose=4 "/path/to/ChromeTabManager.app"
spctl --assess --type execute "/path/to/ChromeTabManager.app"
```

For a DMG:
```bash
# Sign the DMG
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
  --timestamp \
  "/path/to/TabPilot.dmg"

# Verify
codesign --verify --verbose=4 "/path/to/TabPilot.dmg"
```

### 2. Prepare for Notarization
Create an app-specific password for notarytool if you use two-factor authentication:
1. Go to appleid.apple.com
2. Security → App-Specific Passwords → Generate Password
3. Label it "notarytool" or similar
4. Store this password securely

Add this to your keychain for easier use:
```bash
xcrun notarytool store-credentials \
  --keychain-profile "AC_PASSWORD" \
  --apple-id "your-apple-id@domain.com" \
  --password "your-app-specific-password" \
  --team-id "your-team-id"
```

### 3. Submit for Notarization
```bash
# Submit the DMG for notarization
xcrun notarytool submit "/path/to/TabPilot.dmg" \
  --keychain-profile "AC_PASSWORD" \
  --wait

# The --wait flag makes it poll until completion (recommended for scripting)
# Without --wait, you'll get an ID to check later with:
# xcrun notarytool log <id> --keychain-profile "AC_PASSWORD"
```

### 4. Handle Notarization Results
The submission will return one of three statuses:
- **success**: Notarization passed
- **invalid**: Notarization failed due to issues
- **in-progress**: Still processing (only if you didn't use --wait)

If successful, you'll receive a log URL you can check:
```bash
xcrur notarytool log <id> --keychain-profile "AC_PASSWORD"
```

### 5. Staple the Notarization Ticket
```bash
# Staple the notarization ticket to your DMG
xcrun stapler staple "/path/to/TabPilot.dmg"

# Verify the staple worked
xcrun stapler validate "/path/to/TabPilot.dmg"
```

### 6. Final Verification
```bash
# Check that Gatekeeper will accept it
spctl -a -t exec -vvv "/path/to/TabPilot.dmg"

# Look for "accepted" in the output
# You should see something like:
# /path/to/TabPilot.dmg: accepted
# source=Notarized Developer ID
```

## Common Notarization Issues and Fixes

### Issue: "The executable is not signed with a valid signature"
**Fix**: Ensure you've signed the app inside the DMG before signing and notarizing the DMG itself.
- Sign the .app bundle first
- Then create the DMG
- Then sign the DMG
- Then notarize the DMG

### Issue: "The binary lacks an enabled Hardened Runtime"
**Fix**: Your app must be built with hardened runtime enabled:
```bash
# In Xcode build settings:
# Enable Hardened Runtime = YES
# Or via xcodebuild:
OTHER_CODE_SIGN_FLAGS="--options runtime"
```

### Issue: "The entitlements com.apple.security.get-task-allow is not permitted"
**Fix**: This indicates you're trying to notarize a debug build or one with debugging entitlements:
- Ensure you're notarizing a Release build
- Check Entitlements.plist for debugging keys
- Remove get-task-allow entitlement for distribution builds

### Issue: "The algorithm LSMinimumSystemVersion is not recognized"
**Fix**: Info.plist issue - ensure you're using standard keys:
- Remove any custom or malformed keys from Info.plist
- Ensure LSMinimumSystemVersion is a string like "10.15"

### Issue: Notarization takes too long or fails intermittently
**Fix**: 
- Notarization service can be slow (5-15 minutes typical, sometimes longer)
- Retrying often works for transient failures
- Check Apple's system status page for service interruptions
- Try submitting during off-peak hours

## Automation in Build Pipeline

### Script Example (Bash)
Here's a complete notarization script for CI/CD:

```bash
#!/bin/bash
set -e

# Variables
APP_PATH="build/Release/ChromeTabManager.app"
DMG_PATH="dist/TabPilot-${VERSION}.dmg"
KEYCHAIN_PROFILE="AC_PASSWORD"

# Sign the app
echo "Signing app..."
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
  --options runtime \
  --timestamp \
  "$APP_PATH"

# Create DMG
echo "Creating DMG..."
hdiutil create "$DMG_PATH" \
  -srcfolder <(cp -R "$APP_PATH" /tmp/Payload && ln -s /Applications /tmp/Payload/Applications && echo /tmp/Payload) \
  -volname "TabPilot" \
  -fs HFS+ \
  -UDZO

# Sign the DMG
echo "Signing DMG..."
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
  --timestamp \
  "$DMG_PATH"

# Notarize
echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

# Staple
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

# Final verification
echo "Verifying notarization..."
spctl -a -t exec -vvv "$DMG_PATH"

echo "Notarization complete!"
```

### GitHub Actions Example
```yaml
name: Build and Notarize

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'
      
      - name: Build app
        run: |
          xcodebuild -scheme ChromeTabManager \
            -configuration Release \
            -derivedDataPath build
      
      - name: Create DMG
        run: |
          # ... DMG creation steps ...
      
      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
        run: |
          # Store credentials
          xcrun notarytool store-credentials \
            --keychain-profile "AC_PASSWORD" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "${{ secrets.TEAM_ID }}"
          
          # Notarize
          xcrun notarytool submit dist/TabPilot-${VERSION}.dmg \
            --keychain-profile "AC_PASSWORD" \
            --wait
          
          # Staple
          xcrun stapler staple dist/TabPilot-${VERSION}.dmg
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v3
        with:
          name: TabPilot-DMG
          path: dist/TabPilot-${VERSION}.dmg
```

## Best Practices

### 1. Always Notarize the Distribution Artifact
Notarize the DMG (or ZIP/PKG) that users will download, not just the internal .app bundle.

### 2. Keep Records
- Save notarization logs for each version
- Keep track of which notarization ID corresponds to which version
- Store these securely for troubleshooting

### 3. Test Thoroughly
After notarization:
- Test on a clean macOS system (virtual machine or spare device)
- Verify Gatekeeper allows execution without user intervention
- Test update mechanism if using Sparkle
- Confirm the app launches and functions correctly

### 4. Plan for Failures
- Have a process for handling notarization failures
- Maintain communication templates for users if notarization delays release
- Consider automation to retry failed submissions

### 5. Stay Updated
- Apple's notarization requirements evolve
- Check Apple's developer documentation periodically
- Test with latest macOS betas when available
- Monitor developer forums for common issues

## Renewal and Rotation
- Notarization does not expire for a given version of your software
- However, if you need to re-sign or modify the software, you must re-notarize
- Consider rotating your notarization credentials periodically
- If using app-specific passwords, generate new ones every 6-12 months

## Troubleshooting Checklist
When notarization fails:

1. [ ] Verify the exact error from notarization log
2. [ ] Check that you're notarizing a Release build (not Debug)
3. [ ] Confirm Hardened Runtime is enabled in build settings
4. [ ] Ensure no debugging entitlements (get-task-allow) are present
5. [ ] Validate that your app signs correctly before notarization
6. [ ] Check Info.plist for malformed keys
7. [ ] Confirm you're using the correct Apple ID and credentials
8. [ ] Try a simple "Hello World" app to isolate issues
9. [ ] Consult Apple's notaration documentation for the specific error
10. [ ] If all else fails, contact Apple Developer Support with logs