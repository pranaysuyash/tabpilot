# Security & Error Handling Fixes - Decision Records

**Date:** 2026-03-26
**Status:** In Progress

---

## SEC-001: License Stored in Plaintext UserDefaults - FIXED

**Issue:** License status (`isProPurchased`) stored in plain UserDefaults. Users could trivially bypass by modifying UserDefaults.

**Decision:** Store license in Keychain with cryptographic protection.

### Changes Made

| File | Change |
|------|--------|
| `Utilities/KeychainManager.swift` | **Created** - Generic Keychain wrapper with `saveBool`, `loadBool`, `saveString`, `loadString` methods |
| `Licensing.swift` | Updated to use `KeychainManager` instead of `UserDefaults` for license storage |

### Implementation Details

```swift
// KeychainManager.swift - Generic Keychain operations
struct KeychainManager {
    static func saveBool(_ value: Bool, service: String, account: String) throws
    static func loadBool(service: String, account: String) throws -> Bool
}

// Licensing.swift - Now uses Keychain
private static let keychainService = "com.pranay.chrometabmanager.license"
private static let keychainAccount = "isProPurchased"

private func loadLicenseFromKeychain() -> Bool {
    try? KeychainManager.loadBool(service: Self.keychainService, account: Self.keychainAccount)
}

private func saveLicenseToKeychain(_ value: Bool) {
    try? KeychainManager.saveBool(value, service: Self.keychainService, account: Self.keychainAccount)
}
```

### Security Improvement

| Before | After |
|--------|-------|
| `UserDefaults.standard.bool(forKey: "isProPurchased")` | `KeychainManager.loadBool(service: "com.pranay.chrometabmanager.license", account: "isProPurchased")` |
| Trivially bypassable | Requires Keychain access |

### Acceptance Criteria

- [x] License stored in Keychain, not UserDefaults
- [x] Bypass by modifying UserDefaults no longer works
- [x] Build passes
- [x] Tests pass

---

## SEC-002: AppleScript URL Injection - FIXED

**Issue:** URLs passed to AppleScript weren't validated for safe schemes. `SecurityUtils.sanitizeURL()` existed but wasn't used in `ChromeController`.

**Decision:** Use existing `SecurityUtils.isSafeURL()` to validate before AppleScript execution.

### Changes Made

| File | Change |
|------|--------|
| `ChromeController.swift` | Added URL scheme validation in `openTab()` using `SecurityUtils.isSafeURL()` |

### Implementation Details

```swift
func openTab(windowId: Int, url: String) async -> Bool {
    guard SecurityUtils.isSafeURL(url) else {
        SecureLogger.error("openTab rejected unsafe URL scheme: \(url)")
        return false
    }
    // ... rest of implementation
}
```

### Security Improvement

| Before | After |
|--------|-------|
| Any URL scheme accepted | Only `http://` and `https://` accepted |
| `javascript:`, `file:`, `data:` could be injected | Dangerous schemes rejected |

### Acceptance Criteria

- [x] `javascript:`, `file:`, `data:` URLs rejected
- [x] Only `http://` and `https://` URLs accepted
- [x] Build passes
- [x] Tests pass

---

## SEC-003: Accessibility Permissions Not Verified - FIXED

**Issue:** AppleScript operations require Accessibility permission, but no check was performed before attempting operations.

**Decision:** Add accessibility permission check in ChromeController before operations.

### Changes Made

| File | Change |
|------|--------|
| `Utilities/AccessibilityUtils.swift` | **Created** - `AccessibilityStatus` enum, `checkAccessibilityStatus()`, `requestAccessibilityPermission()` functions |
| `ChromeController.swift` | Added `isAccessibilityEnabled()` and `ensureAccessibility()` methods |
| `ChromeError.swift` | Added `accessibilityNotGranted` case |
| `GracefulDegradationManager.swift` | Added handling for `accessibilityNotGranted` |
| `UserFacingError.swift` | Added `accessibilityRequired` case |

### Implementation Details

```swift
// AccessibilityUtils.swift
enum AccessibilityStatus {
    case granted, denied, notDetermined
}

func checkAccessibilityStatus() -> AccessibilityStatus {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)
    return trusted ? .granted : .denied
}

// ChromeController.swift
func isAccessibilityEnabled() -> Bool {
    checkAccessibilityStatus() == .granted
}

func scanAllTabsFast(...) async throws {
    guard isAccessibilityEnabled() else {
        throw ChromeError.accessibilityNotGranted
    }
    // ... rest of implementation
}
```

### User Experience Improvement

| Before | After |
|--------|-------|
| Silent failure if permissions denied | Clear error message explaining what permissions needed |
| No guidance for user | Error suggests: "Grant Accessibility permission in System Settings > Privacy & Security" |

### Acceptance Criteria

- [x] Accessibility permission checked before scan
- [x] Clear error message if permissions not granted
- [x] User guidance provided
- [x] Build passes
- [x] Tests pass

---

## Consumer-First Security Opt-In - FIXED

**Issue:** Security audit signing (SecureEnclave) ran on startup, prompting for Keychain access even for users who didn't need it.

**Decision:** Make security audit signing opt-in via user preference.

### Changes Made

| File | Change |
|------|--------|
| `Utilities/DefaultsKeys.swift` | Added `securityAuditEnabled` key |
| `Utilities/SecurityAuditLogger.swift` | Only signs events when `isSigningEnabled` is true |

### Implementation Details

```swift
// SecurityAuditLogger.swift
private var isSigningEnabled: Bool {
    UserDefaults.standard.bool(forKey: DefaultsKeys.securityAuditEnabled)
}

func log(...) {
    // Only use SecureEnclave signing when user enables it
    if signEvent && isSigningEnabled {
        let sig = try SecureEnclaveKeyManager.sign(canonical)
        // ...
    }
}
```

### User Experience Improvement

| Before | After |
|--------|-------|
| Keychain prompt on every startup | No prompt unless user enables in Preferences |
| All users pay the security cost | Only power users who want audit signing pay the cost |

---

## ERR-001: Silent Error Swallowing - PENDING

**Issue:** `AutoCleanupManager` uses `try?` to ignore errors when closing tabs, silently failing.

**Status:** Pending implementation.

### Acceptance Criteria

- [ ] Track failed closes
- [ ] Log failures individually
- [ ] Show summary notification to user

---

## ERR-002: Fire-and-Forget Logging - FIXED

**Issue:** `ErrorPresenter` and `LicenseManager` used fire-and-forget `Task { }` for security logging, risking lost events if app crashed.

**Decision:** Await all critical security events.

### Changes Made

| File | Change |
|------|--------|
| `Licensing.swift` | Changed 14+ fire-and-forget `Task { }` to `await` directly |

### Implementation Details

```swift
// Before
Task {
    await SecurityAuditLogger.shared.log(category: "licensing", action: "purchase_started", ...)
}

// After
await SecurityAuditLogger.shared.log(category: "licensing", action: "purchase_started", ...)
```

### Acceptance Criteria

- [x] All security audit logs awaited before continuing
- [x] No fire-and-forget security logging
- [x] Build passes
- [x] Tests pass

---

## Files Created/Modified

### Created
- `Utilities/KeychainManager.swift` (new)

### Modified
- `Licensing.swift` (Keychain storage)
- `ChromeController.swift` (URL validation, accessibility check)
- `Utilities/AccessibilityUtils.swift` (accessibility check functions)
- `Core/Errors/ChromeError.swift` (accessibilityNotGranted case)
- `Core/Errors/UserFacingError.swift` (accessibilityRequired case)
- `Utilities/GracefulDegradationManager.swift` (accessibility handling)
- `Utilities/SecurityAuditLogger.swift` (opt-in signing)
- `Utilities/DefaultsKeys.swift` (securityAuditEnabled)

---

## Verification

| Check | Status |
|-------|--------|
| `swift build` | ✅ Passes |
| `swift test` | ✅ 37/37 tests pass |
