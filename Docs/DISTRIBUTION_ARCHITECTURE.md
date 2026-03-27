# Distribution Architecture

## Overview
This document outlines the distribution strategy for Chrome Tab Manager (TabPilot) for direct distribution outside the Mac App Store.

> **2026-03-26 update:** Purchase flow moved to landing page. See `PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`.

## Purchase & Download Flow

```
Landing page (tabpilot.app)
  → User clicks "Buy Now — $19.99"
  → Dodo Payments hosted checkout
  → Post-purchase page shows DMG download link (S3)
  → Download link also emailed to user

Restore flow:
  → User returns to landing page
  → Enters email in "Already purchased?" section
  → Dodo API confirms purchase
  → Download link shown again
```

The app itself has no purchase, licensing, or entitlement code. $19.99 to download, works forever.

## Distribution Channels
- Primary: Direct download via website (S3/CloudFront)
- Artifact format: Notarized DMG file
- Delivery: Public download links with versioned artifacts

## Versioning Strategy
- Semantic versioning (MAJOR.MINOR.PATCH)
- Each version gets a unique DMG filename: `TabPilot-{version}.dmg`
- Old versions retained for 90 days for rollback capability
- Latest version always available at `TabPilot-latest.dmg` (redirects to current)

## Integrity Verification
- SHA-256 checksums published alongside each DMG
- Checksums displayed on download page and in release notes
- Automatic verification during Sparkle update process

## Update Mechanism
- Sparkle framework for automatic, secure updates
- Update feed hosted at `https://updates.tabpilot.app/appcast.xml`
- DSA signatures for update authenticity
- Delta updates supported to minimize download size

## Notarization Process
All distribution artifacts must be notarized by Apple:
1. Build and sign app with Developer ID
2. Create DMG with signed app inside
3. Submit DMG to Apple notarytool
4. Staple notarization ticket to DMG
5. Publish to distribution channel

## Fallback Options
- If primary download fails, mirror available via GitHub Releases
- Email fallback: Purchase confirmation includes direct download links
- Manual verification: Users can verify checksums via Terminal

## Rollback Procedure
1. User downloads previous version from archive
2. Installs over current version (standard macOS upgrade behavior)
3. Preferences and data preserved via standard app container
4. Sparkle will not auto-update back to problematic version without user intervention