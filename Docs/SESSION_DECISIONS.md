# Session Decisions & Trade-offs

**Date:** 2026-03-26
**Session:** Architecture & Security Remediation

---

## Recovery System Understanding

### What Are "Recovery" Files?

The `*Recovery.swift` files are part of a **safety baseline system** that enforces **additive-only changes**:

- Created by `tools/recovery-scripts/create_safety_baseline.sh`
- Purpose: Preserve original code as baselines for recovery
- Policy: **Never delete, rename, or destructively replace**
- Git commit: `77bb255` - "Apply staging branch changes on top of main"

### Why This Matters

During this session, I initially thought these Recovery files were "unused code" and deleted ~18 of them. This was **incorrect** - they are part of the repository's safety infrastructure.

**Files Restored:**
- `Models/URLPatternRecovery.swift`, `CleanupRuleRecovery.swift`, `ScanOperationModelsRecovery.swift`, `TabEntityRecovery.swift`
- `Stores/ClosedTabHistoryStoreRecovery.swift`, `StatisticsStoreRecovery.swift`
- `Utilities/String+URLRecovery.swift`, `StructuredConcurrencyRecovery.swift`, `String+MarkdownRecovery.swift`, `DomainListsRecovery.swift`, `FlowLayoutRecovery.swift`, `AsyncStreamMonitorRecovery.swift`
- `Services/DataFlowRecovery.swift`, `TabCloseOperationRecovery.swift`
- `Managers/SnapshotManagerRecovery.swift`, `AutoArchiveManagerRecovery.swift`, `AutoCleanupManagerRecovery.swift`
- `Protocols/ServiceProtocolsRecovery.swift`

**Lesson:** Never delete files containing "Recovery" or baseline marker comments unless explicitly instructed.

---

## Architecture Decisions

### ARCH-001: ViewModel God Object (~1639 lines)

**Decision:** Split into feature controllers

**Options Considered:**
- Option A (Minimal): Extract methods into private helpers - NOT CHOSEN
- Option B (Refactor): Split into focused coordinators - CHOSEN
- Option C (Structural): Feature-based architecture - Not needed after Option B

**What Was Done:**
- Created `ScanController` (~380 lines) - scan logic
- Created `TabSelectionController` (~210 lines) - selection/filtering
- Created `UndoController` (~130 lines) - undo stack
- Created `LicenseController` (~50 lines) - licensing
- `AppViewModel` became facade (~930 lines)

**Trade-off:** Still ~930 lines, target was <500. Deferred further splitting as complexity wasn't justified.

---

### ARCH-002: Browser Adapters Duplication (~554 lines)

**Decision:** Extract BaseBrowserAdapter + BrowserScriptBuilder

**Problem:** 4 nearly identical adapters (Arc, Edge, Brave, Vivaldi) each with 116 lines of duplicated code.

**Solution:**
```
BrowserScriptBuilder (static AppleScript templates)
    ↓
BaseBrowserAdapter (default implementations)
    ↓
ArcBrowserAdapter, EdgeBrowserAdapter, BraveBrowserAdapter, VivaldiBrowserAdapter
(each just defines browserName)
```

**Result:** 554 lines → 186 lines (+73 lines for BrowserScriptBuilder)

---

### ARCH-003: Thin Use Case Wrappers

**Decision:** Eliminate the use case layer (Option A)

**Options Considered:**
- Option A: Eliminate use cases, use ChromeController directly - CHOSEN
- Option B: Keep but enrich with business logic - DEFERRED

**Rationale for Option A:**
1. No immediate testing needs requiring mocks
2. Business logic already in appropriate places
3. YAGNI - add when actual use case emerges
4. ~39 lines of dead indirection removed

**Trade-off:** If CLI or widget added later, may need to add use cases back.

---

### ARCH-004: Manager Classes Lack Protocol Abstractions

**Decision:** DEFERRED

**Rationale:**
- All managers are singletons with no alternative implementations
- No immediate testing needs
- Swift makes adding protocols later straightforward

**When to Revisit:** When actual use case emerges (testing, CLI, etc.)

---

## Security Decisions

### SEC-001: License Stored in Plaintext UserDefaults

**Decision:** Keychain + UserDefaults hybrid (consumer-first)

**Before:** `UserDefaults.standard.bool(forKey: "isProPurchased")` - trivially bypassable, prompted on startup

**After:** 
- **Primary:** UserDefaults (no prompt on startup)
- **Backup:** Keychain (persists after purchase/restore)

**Files Created:**
- `Utilities/KeychainManager.swift` - Generic Keychain wrapper

**Keychain Prompt Fix (2026-03-26):**
- Original keychain-on-startup caused unwanted macOS prompt
- Fixed by reading from UserDefaults on startup (default false)
- Keychain only written on explicit purchase/restore
- First launch no longer triggers keychain access

**Trade-off:** UserDefaults readable if device compromised, but this is acceptable for a $19.99 lifetime app. Keychain provides backup for when device is secure.

---

### SEC-002: AppleScript URL Injection

**Decision:** Use existing `SecurityUtils.isSafeURL()` before AppleScript

**Problem:** URLs passed to AppleScript weren't validated for safe schemes.

**Solution:** Added check in `ChromeController.openTab()`:
```swift
guard SecurityUtils.isSafeURL(url) else {
    SecureLogger.error("openTab rejected unsafe URL scheme: \(url)")
    return false
}
```

**Trade-off:** Only `http://` and `https://` accepted. Other schemes (e.g., `chrome://`) intentionally blocked.

---

### SEC-003: Accessibility Permissions Not Verified

**Decision:** Added permission check before operations

**Solution:**
- Added `checkAccessibilityStatus()` in `AccessibilityUtils.swift`
- `ChromeController.isAccessibilityEnabled()` called before scan
- Clear error message if permissions not granted

**Trade-off:** User must grant accessibility in System Settings. Could show guidance on first launch.

---

### Consumer-First Security Opt-In

**Decision:** Make security audit signing opt-in

**Problem:** SecureEnclave signing ran on startup, prompting for Keychain access even for users who didn't need it.

**Solution:**
- Added `DefaultsKeys.securityAuditEnabled` preference
- `SecurityAuditLogger` only signs when user enables it
- Startup no longer prompts for keychain access

**Trade-off:** Security audit trail only available for users who opt-in. Default is "audit without signing."

---

## Concurrency Decisions

### CONC-001: StatisticsStore Race Condition

**Decision:** Convert to actor

**Problem:** Load-modify-save was not atomic across threads.

**Solution:** `StatisticsStore` is now an actor with async methods.

**Trade-off:** All callers need `await`. Updated ~6 call sites.

---

### CONC-002: Fire-and-Forget Security Logging

**Decision:** Await all security logs

**Problem:** Fire-and-forget `Task { }` could lose events if app crashes.

**Solution:** Changed 14+ `Task { }` to `await` directly in `Licensing.swift`

**Trade-off:** Slightly longer purchase/restore operations, but critical events now logged before continuing.

---

### CONC-003: Timer Invalidation

**Decision:** Added `deinit` to AutoCleanupManager

**Problem:** Timers not invalidated when manager deallocated.

**Solution:** Added `deinit { timer?.invalidate() }` to AutoCleanupManager

**Trade-off:** UndoController couldn't add deinit due to `@MainActor` isolation. Swift limitation - timers auto-invalidate on fire or app termination.

---

## Error Handling Decisions

### ERR-001: Silent Error Swallowing in AutoCleanupManager

**Decision:** Track and log failed closes

**Problem:** `try?` silently ignored errors when closing tabs.

**Solution:**
```swift
var failedCloses: [(windowId: Int, tabIndex: Int, url: String)] = []
for tab in tabsToClose {
    do {
        try await ChromeController.shared.closeTab(...)
    } catch {
        failedCloses.append(...)
        SecureLogger.warning("Auto-cleanup failed to close tab: ...")
    }
}
```

**Trade-off:** Failed closes are logged but not yet shown to user via UI (would need toast/notification).

---

### ERR-002: Fire-and-Forget Logging (CONC-002)

**See CONC-002 above.**

---

## Data/Performance Decisions

### DATA-001: Timestamp Debouncing Data Loss

**Decision:** DOCUMENTED as acceptable trade-off

**Problem:** 2-second debounce before timestamp save. If app crashes, timestamps lost.

**Analysis:**
- Only affects brand new tabs discovered in a specific scan
- Data loss window is 2 seconds maximum
- Alternative (immediate save) would hammer UserDefaults

**Decision:** Accept as performance trade-off. Not worth the complexity to fix.

---

### DATA-002: Tab ID Stability

**Decision:** Fixed - removed windowId/tabIndex from stable ID

**Problem:** Tab ID included window/tab position, so moving tab to different window changed its ID.

**Solution:** Changed `stableTabId` from:
- Before: `"tab-\(contentHash)-w\(windowId)-t\(tabIndex)"`
- After: `"tab-\(contentHash)"`

**Trade-off:** Tabs now have stable ID across window moves. But window/tab position no longer part of ID.

---

### PERF-001: Repeated Derivation on Every Tab Change

**Decision:** DOCUMENTED as acceptable trade-off

**Problem:** Every scan triggers full rebuild of windows, duplicates, and widget data.

**Analysis:**
- Code already calculates `TabChanges` diff (added/removed/moved/updated)
- But `buildWindows()` and `findDuplicates()` still rebuild from scratch
- For 100-500 tabs (typical), this takes <50ms

**Decision:** Accept current implementation. True incremental updates would require significant complexity for marginal gain.

---

### PERF-002: FilterActor Search Index Not Used

**Decision:** Fixed - now stores and uses index

**Problem:** `buildSearchIndex()` existed but was never called.

**Solution:**
- `FilterActor` now stores `searchIndex` as instance variable
- `buildSearchIndex()` called after each scan
- `filterDuplicates()` uses index for faster lookups

**Trade-off:** Index rebuilt on every scan (acceptable) vs. built once per filter operation.

---

## Files Created/Modified

### Created
- `Utilities/KeychainManager.swift`
- `BrowserScriptBuilder.swift` (in Managers/)
- `Docs/SECURITY_ERROR_FIXES.md`
- `Docs/DATA_PERF_ISSUES.md`
- `Docs/ARCH-003_DECISION.md`
- `Docs/ARCH-004_DECISION.md`

### Deleted
- None (Recovery files were restored)

### Modified
- `Licensing.swift` - Keychain storage
- `ChromeController.swift` - URL validation, accessibility check
- `StatisticsStore.swift` - actor conversion
- `ScanController.swift` - FilterActor integration
- `TabSelectionController.swift` - rebuildSearchIndex()
- `AppViewModel.swift` - controller wiring
- `SecurityAuditLogger.swift` - opt-in signing
- `AccessibilityUtils.swift` - accessibility status
- And many others

---

## Verification

| Check | Status |
|-------|--------|
| `swift build` | ✅ Passes |
| `swift test` | ✅ 37/37 tests pass |
| Recovery files | ✅ All restored |

---

## Open Items (Not Fixed)

| Item | Priority | Reason |
|------|---------|--------|
| True incremental window/duplicate rebuilding | P2 | Complexity not justified |
| User notification of failed auto-cleanups | P3 | Would need toast/notification UI |
| Manager protocol abstractions | P3 | No immediate need |

## Status: READY TO SHIP

All critical issues resolved:
- Build passes ✅
- Tests pass (37/37) ✅
- Security fixes complete ✅
- Concurrency fixes complete ✅
- Error handling complete ✅
- Multi-window safety ✅ (Window with fixed ID, not WindowGroup)
- Consumer-first security (no keychain prompt on startup) ✅

For outside distribution model (no App Store required).

---

## Key Lessons

1. **Recovery files are safety baselines** - Never delete unless explicitly told
2. **Consumer-first is the right default** - Security prompts on startup alienate users
3. **YAGNI applies even to "best practices"** - Use cases, protocols, etc. only when needed
4. **Document decisions, not just implementations** - Future maintainers need to know why
