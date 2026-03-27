# ARCH-003: Thin Use Case Wrappers - Decision Record

**Date:** 2026-03-24
**Status:** COMPLETED (Option A)

## Issue Summary

**Title:** Thin Use Case Wrappers Add Indirection Without Value

**Evidence:**
- `UseCases.swift:19-23` - `DefaultScanTabsUseCase` just delegates to `ChromeController.shared.scanAllTabsFast()`
- `UseCases.swift:25-29` - `DefaultCloseTabsUseCase` just delegates to `ChromeController.shared.closeTabsDeterministic()`

## Options Considered

### Option A: Eliminate the Use Case Layer (CHOSEN)
**Decision:** Remove `UseCases.swift` entirely. Use `ChromeController` directly.

**Rationale:**
1. **Less code = fewer bugs** - Pre-launch, simplicity matters
2. **Direct is simpler** - `ChromeController` is the real abstraction
3. **No technical debt** - Not carrying unnecessary patterns
4. **YAGNI** - Add use cases when actual business logic needs sharing

**Changes Made:**
- Deleted `Sources/ChromeTabManager/Services/UseCases.swift`
- Updated `ScanController` to use `ChromeController.shared.scanAllTabsFast()` directly
- Updated `AppViewModel` to use `ChromeController.shared.closeTabsDeterministic()` directly

**Results:**
- Lines removed: ~39
- Build passes: ✅
- Tests pass: ✅ (37/37)

### Option B: Keep but Enrich with Business Logic
**Decision:** Deferred for future consideration.

**When This Would Make Sense:**
- If we add multiple entry points (CLI, API, widget) that need consistent business logic
- If we need to share business rules between macOS app and potential iOS app
- If we want to unit test business logic in isolation from AppleScript calls

**What Would Be Needed:**
- Move URL normalization into use case
- Move protected domain enforcement into use case
- Move license tier checks into use case
- Add mock implementations for testing

**Estimated Effort:** 2-3 days

## Future Consideration (Option B)

If the app grows to need use cases, consider:

```swift
// Example enriched use case
protocol CloseTabsUseCaseProtocol {
    func execute(windowId: Int, targets: [(url: String, title: String)]) async -> CloseResult
    // Business rules would be encapsulated:
    // - Protected domain check
    // - License tier enforcement
    // - Undo tracking
}

struct CloseTabsUseCase: CloseTabsUseCaseProtocol {
    func execute(windowId: Int, targets: [(url: String, title: String)]) async -> CloseResult {
        // 1. Filter protected domains
        // 2. Check license tier
        // 3. Execute close via ChromeController
        // 4. Record undo action
        // 5. Return result
    }
}
```

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| Either use cases encapsulate business logic OR they're eliminated | ✅ Eliminated |
| Build passes | ✅ |
| Tests pass | ✅ (37/37) |

## Related Issues

- ARCH-001: ViewModel God Object (COMPLETED)
- ARCH-002: Browser Adapters Duplication (COMPLETED)
