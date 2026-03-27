# Update Process

## Overview
This document outlines the update strategy for Chrome Tab Manager (TabPilot) using the Sparkle framework.

## Why Sparkle
- Industry standard for macOS direct distribution updates
- Secure by design (requires signed updates)
- Well-maintained and battle-tested
- Supports delta updates to reduce bandwidth
- Provides excellent user experience

## Architecture

### Components
1. **Appcast XML**: `https://updates.tabpilot.app/appcast.xml`
   - Hosted on S3/CloudFront
   - Contains release notes, version info, and download URLs
   - Secured with HTTPS only

2. **Update Signatures**: Ed25519 signatures (Sparkle 2)
   - Generated with a private signing key kept offline
   - Public Ed25519 key bundled in the app
   - Ensures update authenticity for Sparkle 2 clients

3. **Delta Updates**: 
   - Generated using `delta` tool from Sparkle
   - Only downloads changed binaries
   - Reduces update size by 60-90%

4. **Update Check Interval**: 
   - Automatic check every 24 hours
   - Manual check available via Menu Bar → Check for Updates
   - Immediate check on app launch (optional setting)

### Update Flow
1. Sparkle framework checks appcast on schedule/launch
2. Compares current version with latest in appcast
3. If newer version available:
   a. Presents update notification to user
   b. User can: Install, Skip Version, Remind Later, or View Notes
   c. If Install: Downloads update (delta if available)
   d. Verifies signature using bundled public key
   e. If valid: Installs update and relaunches app
   f. If invalid: Shows security warning and aborts

## Release Channel Strategy
- **Stable**: Default channel for all users
- **Beta**: Opt-in for testing new features (via hidden preference)
- Each channel has separate appcast

## Versioning in Appcast
- Each item represents a version
- Minimum length descriptions for App Store compatibility
- Release notes in HTML format
- Includes:
  - Version string
  - Short version string
  - Release date
  - Description (release notes)
  - Download URL
  - Minimum system requirement

## Implementation Details

### App Integration
- Sparkle bundled via Swift Package Manager
- `SPUStandardUpdaterController` owned by `UpdateManager`
- Feed URL configured in Info.plist
- Public Ed25519 key embedded in app resources

### Required Info.plist Entries
Add these entries to your `Info.plist` file for Sparkle to function properly:

```xml
<!-- Sparkle Feed URL - Point to your appcast.xml hosted on HTTPS -->
<key>SUFeedURL</key>
<string>https://updates.tabpilot.app/appcast.xml</string>

<!-- Public DSA Key File - Name of the .pem file in your app resources -->
<key>SUPublicDSAKeyFile</key>
<string>sparkle_pub.pem</string>

<!-- Enable Automatic Update Checks (optional, default YES) -->
<key>SUEnableAutomaticChecks</key>
<true/>

<!-- Update Check Interval in seconds (optional, default 86400 = 24 hours) -->
<key>SUUpdateCheckInterval</key>
<integer>86400</integer>

<!-- Allow App to Pause for Relaunch (optional) -->
<key>SUAllowsRelaunch</key>
<true/>

<!-- Beta Channel Identifier (optional, for beta users) -->
<key>SUBetaIdentifier</key>
<string>beta</string>
```

### Required App Changes
1. Add Sparkle dependency via Swift Package Manager
2. Initialize `SPUStandardUpdaterController` early in app startup (for example in `UpdateManager`)
3. Wire the menu item or button to `checkForUpdates(_:)` / `checkForUpdates(nil)` on the updater controller
4. Optionally implement Sparkle 2 delegate hooks (`SPUUpdaterDelegate` / `SPUStandardUserDriverDelegate`) when custom behavior is needed:
   - update discovery / filtering
   - download lifecycle hooks
   - failure reporting
   - custom user-driver presentation

### Generating Signing Keys
Sparkle 2 uses Ed25519 signing by default. Generate your keypair with Sparkle's tooling:

```bash
# Generate a Sparkle Ed25519 key pair (keep the private key secret)
generate_keys
```

**Important**: Never commit your private signing key to version control.

### Security Considerations
- Private key never leaves secure build environment
- Public key bundled in app (rotated annually)
- Updates only served over HTTPS
- Strict version checking (no downgrades allowed)
- Sandboxed update process if app is sandboxed

## Release Procedure

### Pre-Release Checks
1. [ ] Build signed and notarized
2. [ ] Generate Sparkle update items
3. [ ] Create delta updates (optional but recommended)
4. [ ] Update appcast XML with new version
5. [ ] Publish appcast to updates server
6. [ ] Upload DMG to updates server
7. [ ] Test update flow on clean machine
8. [ ] Verify signature validation works
9. [ ] Check that launch after update preserves data
10. [ ] Confirm menu bar updater works

### Post-Release Monitoring
1. [ ] Monitor update adoption via server logs
2. [ ] Check for failed update reports
3. [ ] Monitor crash reports for new version
4. [ ] Gather user feedback via support channels
5. [ ] Be prepared to pause rollout if critical issues found

## Rollback Strategy
1. If critical bug found in new release:
   a. Immediately mark version as "yanked" in appcast (remove item)
   b. Communicate issue via website/status page
   c. Support team prepares guidance for affected users
   d. Users can manually download previous version from archive
   e. Next release will include fix and proper version jump

## FAQ

**Q: Can users disable updates?**
A: Yes, via Preferences → General → "Automatically check for updates"

**Q: What happens if update verification fails?**
A: App shows security warning and does not install. User remains on current version.

**Q: Are updates mandatory?**
A: No. Users can choose to skip versions or disable automatic checks.

**Q: How large are typical updates?**
A: With delta updates, typically 5-15MB. Full updates 40-60MB.

**Q: What if user is offline when update available?**
A: Update will be offered next time online and app checks for updates.

## Appcast.xml Skeleton

Your appcast.xml is hosted at the URL specified in `SUFeedURL`. Here's the structure:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>TabPilot Changelog</title>
    <link>https://updates.tabpilot.app/appcast.xml</link>
    <description>Most recent changes with links to the download.</description>
    <language>en</language>
    
    <!-- Example Release Item -->
    <item>
      <title>Version 2.5.0</title>
      <sparkle:version>2.5.0</sparkle:version>
      <sparkle:shortVersionString>2.5.0</sparkle:shortVersionString>
      <sparkle:releaseDate>2026-03-26T12:00:00Z</sparkle:releaseDate>
         <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's New in TabPilot 2.5.0</h2>
        <ul>
          <li>New feature: Improved tab grouping</li>
          <li>Bug fix: Resolved memory leak during long sessions</li>
          <li>Performance: 40% faster tab scanning</li>
        </ul>
      ]]></description>
      <enclosure url="https://updates.tabpilot.app/TabPilot-2.5.0.dmg"
                 sparkle:length="52428800"
                 sparkle:edSignature="base64-ed25519-signature-goes-here"
                 type="application/octet-stream"/>
    </item>
    
    <!-- Previous releases follow same structure -->
    
  </channel>
</rss>
```

### Appcast Item Attributes

| Attribute | Description | Required |
|-----------|-------------|----------|
| `sparkle:version` | Machine-readable version (CFBundleVersion) | Yes |
| `sparkle:shortVersionString` | User-visible version (CFBundleShortVersionString) | Yes |
| `sparkle:releaseDate` | ISO 8601 date of release | Yes |
| `sparkle:minimumSystemVersion` | Minimum macOS version required | No |
| `sparkle:dsaSignature` | Legacy DSA signature for Sparkle 1 clients | No |
| `enclosure url` | Direct download URL for the update | Yes |
| `enclosure sparkle:length` | File size in bytes | Yes |
| `enclosure sparkle:edSignature` | Ed25519 signature (Sparkle 2.x) | No |

### Generating Sparkle Signatures

```bash
# Sign a DMG with Ed25519 (Sparkle 2.x)
./sign_update TabPilot.dmg Ed25519Key.pem

# Get signature for appcast item
./sign_update TabPilot-2.5.0.dmg Ed25519Key.pem
```

### Delta Updates

For delta updates that only download changed portions:

```xml
<item>
  <title>Version 2.5.1</title>
  <sparkle:version>2.5.1</sparkle:version>
  <sparkle:shortVersionString>2.5.1</sparkle:shortVersionString>
  <sparkle:releaseDate>2026-03-27T12:00:00Z</sparkle:releaseDate>
  <sparkle:deltaFrom="2.5.0">DeltaUpdate</sparkle:deltaFrom>
  <enclosure url="https://updates.tabpilot.app/TabPilot-2.5.1.delta"
             sparkle:length="5242880"
             type="application/octet-stream"/>
</item>
```

Generate delta updates using the `delta` tool from Sparkle utilities.