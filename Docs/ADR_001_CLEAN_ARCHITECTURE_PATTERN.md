# ADR-001: Clean Architecture Pattern (Designed but Not Adopted)

**Date:** 2026-03-27  
**Status:** FUTURE IMPROVEMENT  
**Source:** Analysis of deleted Recovery files

---

## Executive Summary

The Recovery files (now deleted) contained a designed but unimplemented clean architecture pattern using Repository protocols and typed Result types. This pattern would improve code separation, testability, and maintainability. Currently, the codebase uses a simpler direct-call architecture.

---

## Current Architecture (What Exists)

### Direct ViewModel → Controller Pattern

```
AppViewModel
    ↓ (direct calls)
ChromeController.shared
    ↓ (AppleScript)
Chrome Browser
```

**Current call signatures:**
```swift
// Scan returns a tuple
let (tabs, telemetry) = try await ChromeController.shared.scanAllTabsFast { ... }

// Close returns a tuple
let (closed, failed, ambiguous) = await ChromeController.shared.closeTabsDeterministic(...)
```

### Problems with Current Architecture

1. **Tight Coupling**: ViewModels directly depend on `ChromeController` singleton
2. **Hard to Test**: Can't mock ChromeController for unit tests
3. **Tuple Returns**: `closed`, `failed`, `ambiguous` is unclear; no error details
4. **No Clean Boundaries**: Business logic mixed with infrastructure

---

## Designed Clean Architecture (What Was Planned)

### Repository Pattern with Protocols

```
AppViewModel
    ↓ (protocol)
ChromeTabRepositoryProtocol
    ↓ (implementation)
ChromeTabRepository
    ↓
ChromeController
    ↓ (AppleScript)
Chrome Browser
```

### Designed Protocols

```swift
// 1. Tab Operations Repository
protocol ChromeTabRepositoryProtocol: Actor {
    var isChromeRunning: Bool { get async }
    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> ScanResult
    func closeTabs(windowId: Int, targets: [(url: String, title: String)]) async -> CloseResult
    func activateTab(windowId: Int, tabIndex: Int) async throws
    func openTab(windowId: Int, url: String) async -> Bool
}

// 2. Timestamp Persistence Repository
protocol TabTimestampRepositoryProtocol: Actor {
    func load() async -> [String: Date]
    func save(_ timestamps: [String: Date]) async
    func timestamp(for url: String) async -> Date?
    func setTimestamp(_ date: Date, for url: String) async
}

// 3. Protected Domain Persistence Repository
protocol ProtectedDomainRepositoryProtocol: Actor {
    func load() async -> [String]
    func save(_ domains: [String]) async
    func add(_ domain: String) async
    func remove(_ domain: String) async
    func isProtected(_ domain: String) async -> Bool
}
```

### Designed Result Types

```swift
// Scan operation result
struct ScanResult {
    let windows: [WindowEntity]
    let stats: ScanStatsEntity
    let telemetry: ScanTelemetryEntity
}

// Close operation result
struct CloseResult {
    let closedCount: Int
    let failedIds: [String]      // Which tabs failed to close
    let errors: [String]          // Error messages for debugging
}

// Tab target specification
struct TabTarget {
    let windowId: Int
    let tabIndex: Int
    let tabId: String
}
```

### Designed Domain Entities

```swift
// Pure data object for a tab (no presentation logic)
struct TabEntity: Identifiable, Hashable, Codable {
    let id: String
    let windowId: Int
    let tabIndex: Int
    let title: String
    let url: String
    let openedAt: Date
    
    var domain: String { /* computed */ }
    
    // For testing
    static func stub(...) -> TabEntity
}

// Browser window with tabs
struct WindowEntity: Identifiable {
    let windowId: Int
    let tabCount: Int
    let tabs: [TabEntity]
    let activeTabIndex: Int
}

// Scan statistics
struct ScanStatsEntity: Codable {
    let totalTabs: Int
    let windowCount: Int
    let duplicateGroups: Int
    let wastedTabs: Int
    let uniqueUrls: Int
}
```

### Designed Repository Implementation

```swift
actor ChromeTabRepository: ChromeTabRepositoryProtocol {
    private let controller: ChromeController
    
    init(controller: ChromeController = .shared) {
        self.controller = controller
    }
    
    var isChromeRunning: Bool {
        get async { await controller.isChromeRunning() }
    }
    
    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> ScanResult {
        let (tabInfos, telemetry) = try await controller.scanAllTabsFast(progress: progress)
        
        // Convert to domain entities
        let tabEntities = tabInfos.map { TabEntity(from: $0) }
        let windows = /* group by windowId */
        let stats = /* compute statistics */
        
        return ScanResult(windows: windows, stats: stats, telemetry: telemetry)
    }
    
    func closeTabs(windowId: Int, targets: [(url: String, title: String)]) async -> CloseResult {
        let result = await controller.closeTabsDeterministic(windowId: windowId, targets: targets)
        return CloseResult(
            closedCount: result.closed,
            failedIds: [],
            errors: result.ambiguous > 0 ? ["\(result.ambiguous) ambiguous tab(s) skipped"] : []
        )
    }
}
```

---

## Comparison: Current vs Designed

| Aspect | Current | Designed |
|--------|---------|----------|
| **Coupling** | Tight (direct singleton) | Loose (protocol) |
| **Testability** | Low (can't mock) | High (inject mock) |
| **Return Types** | Tuples (unclear) | Named structs (clear) |
| **Error Handling** | Ambiguous count | Error messages array |
| **Failure Tracking** | No ID tracking | `failedIds` array |
| **Domain Logic** | Mixed with infra | Separated |
| **Data Transformation** | In ViewModel | In Repository |

---

## Why It Wasn't Adopted

Based on code analysis, the pattern was designed but:

1. **ChromeTabRepository was never created** - The file doesn't exist
2. **ViewModels still use ChromeController.shared directly** - No protocol injection
3. **Tuple returns persist** - `(closed, failed, ambiguous)` instead of `CloseResult`
4. **No dependency injection** - Controllers are still singletons

The design was good but implementation was never completed.

---

## Recommendations

### Option A: Full Adoption (Recommended for Large Codebase)

1. Implement `ChromeTabRepositoryProtocol`
2. Implement `ChromeTabRepository` wrapping `ChromeController`
3. Inject repository into `AppViewModel` via init
4. Replace tuple returns with `ScanResult`/`CloseResult`
5. Update tests with mock repositories

**Benefits:** Full testability, clean separation, clear error tracking  
**Effort:** Medium (1-2 days)  
**Risk:** Low (incremental migration possible)

### Option B: Partial Adoption (Recommended for Quick Win)

1. Keep direct `ChromeController` calls
2. Add `ScanResult`/`CloseResult` as return types only
3. Track `failedIds` in close operations
4. Add error messages array

**Benefits:** Better error tracking, clearer returns  
**Effort:** Low (2-4 hours)  
**Risk:** Minimal (return type change only)

### Option C: Status Quo (If Working Fine)

Keep current architecture if:
- Codebase is small
- Testing isn't critical
- Tuple returns are clear enough

---

## Current Equivalents (What Exists Instead)

The codebase already has equivalent types that serve similar purposes:

| Designed Type | Existing Equivalent | Notes |
|---------------|---------------------|-------|
| `TabEntity` | `TabInfo` | Better: has `Sendable`, `profileName` |
| `WindowEntity` | `WindowInfo` | Identical structure |
| `ScanTelemetryEntity` | `ScanTelemetry` | Identical structure |
| `ScanStatsEntity` | Computed in ScanController | Inline, not extracted |
| `CloseResult` | Tuple `(closed, failed, ambiguous)` | Less clear |

---

## Test Impact

Clean architecture would enable:

```swift
// Mock repository for testing
class MockChromeTabRepository: ChromeTabRepositoryProtocol {
    var mockScanResult: ScanResult = .init(windows: [], stats: .empty, telemetry: .empty)
    
    func scanAllTabs(...) async throws -> ScanResult {
        return mockScanResult
    }
}

// Test ViewModel without Chrome dependency
func testScanUpdatesUI() async {
    let mock = MockChromeTabRepository()
    mock.mockScanResult = ScanResult(windows: [...], stats: ..., telemetry: ...)
    
    let vm = AppViewModel(tabRepository: mock)
    await vm.scan()
    
    XCTAssertEqual(vm.tabs.count, 5)
}
```

Currently impossible because ViewModels call `ChromeController.shared` directly.

---

## Conclusion

The clean architecture pattern was **designed well but never implemented**. The Recovery files contained the protocol definitions, repository implementations, and result types needed. Existing code already has equivalent domain entities (`TabInfo`, `WindowInfo`, `ScanTelemetry`) that are actually better (include `Sendable`).

**Decision:** This pattern should be documented as a future improvement, not implemented now, since the current architecture is working and the existing types already serve the domain modeling purpose.

**Next Steps:**
1. ✅ Document this ADR
2. If testability becomes critical → adopt Option A
3. If error tracking needs improvement → adopt Option B
4. Otherwise → keep status quo
