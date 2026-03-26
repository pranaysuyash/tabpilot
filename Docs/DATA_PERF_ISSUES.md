# Data & Performance Issues - Decision Records

**Date:** 2026-03-26
**Status:** Documented

---

## DATA-002: Tab ID Stability - FIXED

**Issue:** Tab ID included `windowId` and `tabIndex`, so moving a tab to another window changed its ID, losing history.

**Fix:** Changed `stableTabId` to use content-only hash (url + title) without window/tab position.

```swift
// Before: "tab-\(contentHash)-w\(windowId)-t\(tabIndex)"
// After:  "tab-\(contentHash)"
```

**Acceptance Criteria:**
- [x] Tab moved between windows retains same ID
- [x] openedAt timestamp preserved across moves
- [x] Build passes

---

## DATA-001: Timestamp Debouncing Data Loss - DOCUMENTED

**Issue:** Timestamps saved with 2-second debounce. If app crashes before save, timestamps lost.

### Current Behavior

```swift
private func scheduleTimestampSave() {
    timestampsDirty = true
    timestampSaveTimer?.invalidate()
    timestampSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.saveTimestamps()
        }
    }
}
```

### Analysis

| Aspect | Assessment |
|--------|------------|
| Data lost | First-seen timestamps for new tabs discovered in scan |
| Recovery | On next scan, tabs re-detected as "new" (no openedAt timestamp) |
| Impact | Minor - only affects tab age display, not actual functionality |
| Trade-off | 2-second batching prevents excessive UserDefaults writes |

### Decision

**Accept as performance trade-off.** The 2-second debounce prevents hammering UserDefaults on every scan when thousands of tabs are discovered. Data loss only affects:
- Brand new tabs discovered in that specific scan
- Only until the 2-second timer fires

### Alternative Approaches (Not Implemented)

1. **Immediate save on important operations** - Would require identifying "important" moments
2. **Crash recovery from scan diff** - Can reconstruct from next scan's tab list
3. **Actor-based batched save** - More complex, minimal benefit

---

## PERF-001: Repeated Derivation on Every Tab Change - DOCUMENTED

**Issue:** Every tab change triggers full rebuild of windows, duplicates, and widget data.

### Evidence

```swift
// _performScan() calls after each scan:
buildWindows()        // Rebuilds all windows from scratch
findDuplicates()      // Recalculates all duplicate groups
updateWidgetData()     // Updates widget
```

### Current Implementation

The code already calculates `TabChanges` via `detectTabChanges()`, which identifies:
- `added` - new tabs
- `removed` - deleted tabs
- `updated` - tabs that changed
- `moved` - tabs that changed window/index

However, this diff is not used for incremental updates - all derived state is rebuilt from scratch.

### Analysis

| Aspect | Assessment |
|--------|------------|
| Time Complexity | O(n) for n tabs |
| Typical Use Case | 100-500 tabs = fast enough (<50ms) |
| Edge Case | 1000+ tabs could be slow |

### Decision

**Accept current implementation.** The performance impact is acceptable for typical use cases. True incremental updates would require:
1. Stable window/duplicateGroup IDs
2. Incremental diff-based updates
3. Complex handling of moved tabs in duplicate detection

This is a post-launch optimization if profiling shows it necessary.

### Status

**Pending (deferred to post-launch if needed).**

---

## PERF-002: FilterActor Search Index Not Used - PENDING

**Issue:** `buildSearchIndex()` exists but is never called. Every filter rescans all text.

### Evidence

```swift
// FilterActor.swift
func buildSearchIndex() // Never called
func filterDuplicates() // Re-parses text every time
```

### Fix Direction

Call `buildSearchIndex()` after scan completes, use index in `filterDuplicates()`.

### Status

**Pending implementation.**

---

## Summary

| Issue | Priority | Status |
|-------|----------|--------|
| DATA-001 | P2 | Documented (acceptable trade-off) |
| DATA-002 | P1 | Fixed |
| PERF-001 | P2 | Pending |
| PERF-002 | P3 | Pending |
