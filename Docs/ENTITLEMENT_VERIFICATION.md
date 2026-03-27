# Entitlement Verification

> **SUPERSEDED — 2026-03-26**
> This document describes the OLD in-app entitlement verification architecture (Keychain caching + license keys + backend API).
> **New architecture:** Purchase happens on the landing page only. App has zero payment/licensing code. No entitlement verification in the app.
> See: `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`

---

## Overview
This document describes how Chrome Tab Manager (TabPilot) verifies user purchases for direct distribution.

## Selected Approach: Email-Record-Only with Optional License Key

### Core Mechanism
- Purchase proof: Payment processor records (Dodo Payments) linked to user email
- Verification method: App checks purchase status via secure API call to backend
- Backend validation: Queries payment processor records for email + product purchase
- Caching: Entitlement status securely cached in Keychain for offline use
- Expiration: Cache refreshed every 7 days (requires re-verification)

### Optional License Key (Power User Feature)
- Generated automatically upon purchase
- Sent in purchase confirmation email
- Can be entered manually in app Preferences
- Provides offline verification capability
- Useful for users with restricted network access or privacy concerns

## Verification Flow

### Online Verification (Primary)
1. App launches and checks Keychain for cached entitlement
2. If cache missing or expired (>7 days):
   a. App prompts for user email (if not already known from prior session)
   b. App calls entitlement API: `GET /api/entitlement?email={userEmail}`
   c. Backend verifies with Dodo Payments/webhook records
   d. Backend returns JSON: `{ "isLicensed": true/false, "productId": "...", "purchaseDate": "..." }`
   d. App updates Keychain cache and unlocks features accordingly
3. If cache valid: Use cached status

### Offline Verification (Fallback)
1. If network unavailable and no valid cache:
   a. App remains in free/restricted mode
   b. User notified: "Unable to verify license. Some features limited."
   c. Option to enter license key for offline verification
   d. If valid key entered: Unlock Pro features and cache status

### License Key Verification
1. User enters key in Preferences → License
2. App validates key format and cryptographic signature
3. If valid: Unlock features and cache entitlement status
4. Key tied to purchase email; cannot be transferred
5. Key can be regenerated via support if lost

## Technical Implementation

### Backend API
- Endpoint: `GET /api/entitlement`
- Parameter: `email` (URL-encoded, lowercase, trimmed)
- Response: 
  ```json
  {
    "isLicensed": true,
    "productId": "com.pranay.chrometabmanager.lifetime",
    "purchaseDate": "2026-03-26T10:30:00Z",
    "expiresAt": null
  }
  ```
- Error responses:
  - 400: Invalid email format
  - 404: No purchase found for email
  - 503: Service temporarily unavailable

### Keychain Storage
- Service: `com.pranay.chrometabmanager.entitlement`
- Account: `verification`
- Stores: JSON string with isLicensed, productId, purchaseDate, expiresAt
- Accessible only to TabPilot (via app identifier)

### License Key Format
- Format: `TPIL-{8hex}-{8hex}-{8hex}` (e.g., `TPIL-A1B2C3D4-E5F60718-9ABCDEF0`)
- Cryptographic signature: HMAC-SHA256(secretKey, email + productId + timestamp)
- Secret key stored only in build environment (never in app)
- Key validation: Recompute HMAC and compare

## User Experience

### First Launch
- App shows empty state with "Scan Now" button
- No license prompts until user attempts Pro feature
- When Pro feature attempted:
  - If unlicensed: Show paywall with purchase option
  - If licensed but unverified: Silent background check
  - If verified: Pro feature works immediately

### Post-Purchase
- Purchase confirmation email includes:
  - Receipt
  - Download link (if applicable)
  - Optional license key
  - Instructions for manual verification if needed
- App automatically verifies in background
- Upon success: Toast notification "License verified successfully"
- Upon failure: Subtle indicator in Preferences, retry on next launch

### License Management
- Preferences → License shows:
  - Current status: Licensed / Unlicensed
  - License key (if generated)
  - "Verify Now" button
  - "Troubleshoot" link to support guide
- Users can:
  - View license key
  - Regenerate license key (via support)
  - Enter license key manually
  - Force re-verification

## Failure Handling & Recovery

### Network Issues
- App gracefully degrades to free mode
- Clear messaging: "Unable to verify license. Check connection."
- Retry automatically on network change or app launch
- Option to enter license key for offline use

### Incorrect Email
- If user changes email, entitlement verification fails
- Recovery path: 
  1. User enters correct email in Preferences → Account
  2. App re-verifies with new email
  3. Or user enters license key

### Clock Skew
- License key validation includes timestamp tolerance (±30 days)
- Server time used for expiration checks (not device time)
- Users warned if device time significantly incorrect

### Compromised Keys
- License keys can be revoked via backend
- Revoked keys show as invalid in app
- Support can issue new key upon verification

## Implementation Tasks

### Immediate (Before Launch)
1. Create minimal backend service for entitlement API
2. Implement Dodo webhook handler to record purchases
3. Build Keychain caching layer in app
4. Add entitlement check to LicenseManager
5. Create license key generation and validation utilities
6. Add license entry UI in Preferences
7. Implement error states and user messaging
8. Add network reachability monitoring
9. Create test suite for verification flows
10. Document API and key format for backend team

### Post-Launch Enhancements
1. Add license key self-service portal
2. Implement key regeneration via authenticated support
3. Add entitlement verification webhooks for other services
4. Implement family sharing verification (if desired)
5. Add offline license validation caching improvements