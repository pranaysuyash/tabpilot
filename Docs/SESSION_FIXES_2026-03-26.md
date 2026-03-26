# Session Fixes - 2026-03-26

## Overview

This document tracks all fixes applied in this session, addressing items 14, 15, 16, 17, 18, and 22 from the review.

---

## Item 14: Window Activation Across Spaces/Monitors/Fullscreen

**Problem**: The `MenuBarController` and `HotkeyManager` used flawed window activation that could land on wrong space or fail with multiple monitors/fullscreen apps.

**Solution**: Implemented `findBestWindow()` pattern that:
- Filters to only visible windows with meaningful size (> 100x100)
- Prefers titled windows (main app windows)
- Falls back to first visible window if no titled window found
- Repositions windows that fall outside the current screen's visible area

**Files Modified**:
- `Sources/ChromeTabManager/Managers/MenuBarController.swift`
- `Sources/ChromeTabManager/Managers/HotkeyManager.swift`

**Code Added**:
```swift
private func findBestWindow() -> NSWindow? {
    let windows = NSApplication.shared.orderedWindows.filter { window in
        window.isVisible && window.frame.width > 100 && window.frame.height > 100
    }
    
    if let mainWindow = windows.first(where: { $0.styleMask.contains(.titled) }) {
        return mainWindow
    }
    
    return windows.first
}
```

---

## Item 15: SuperUser Table View

**Status**: Already implemented and complete.

The `SuperUserTableView` provides sortable columns (Title, Domain, Window, Count, Age) with keyboard navigation support.

---

## Item 16: Session Save/Restore - Name Collision Handling

**Problem**: Saving a session with an existing name would create a duplicate instead of prompting or overwriting.

**Solution**: 
- `SessionStore.saveCurrentTabs()` now checks for existing session with same name (case-insensitive)
- If found, overwrites the existing session
- If not found, inserts new session at the top
- `SaveSessionSheet` shows a warning when name is taken and changes button to "Overwrite"

**Files Modified**:
- `Sources/ChromeTabManager/Models/Session.swift`
- `Sources/ChromeTabManager/Views/SessionView.swift`

**Code Added**:
```swift
func saveCurrentTabs(_ tabs: [TabInfo], name: String, notes: String = "") {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    
    let sessionTabs = tabs.map { SessionTab(tabInfo: $0) }
    let session = Session(name: trimmedName, tabs: sessionTabs, notes: notes)
    
    if let existingIdx = sessions.firstIndex(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
        sessions[existingIdx] = session
    } else {
        sessions.insert(session, at: 0)
    }
    persist()
}

func sessionExists(withName name: String) -> Bool {
    sessions.contains { $0.name.lowercased() == name.lowercased() }
}
```

---

## Item 17: Statistics CSV Export

**Problem**: `StatisticsStore` tracked rich data (domains, tracking sources, tab debt history) but had no way to export.

**Solution**: Added two methods:
- `exportToCSV()` - Returns CSV string with all statistics
- `exportToCSVFile()` - Writes CSV to temp file and returns URL for sharing

**Files Modified**:
- `Sources/ChromeTabManager/Stores/StatisticsStore.swift`

**CSV Includes**:
- Summary section (Total Tabs Closed, Duplicate Tabs Closed, Sessions Count, Total Savings, Tab Debt Score)
- Top Domains by Tab Count
- Top Domains by Duplicate Count
- Top Tracking Sources
- Tab Debt History (if any)

**Code Added**:
```swift
func exportToCSV() -> String { ... }
func exportToCSVFile() -> URL? { ... }
```

---

## Item 18: macOS Version Compatibility

**Problem**: Contradiction between Package.swift (macOS v15) and documentation (macOS 13+).

**Solution**: Unified to macOS 14+ (Sonoma) across all files.

**Files Modified**:
- `Package.swift` - Changed from `.macOS(.v15)` to `.macOS(.v14)`
- `Sources/ChromeTabManager/Info.plist` - Already set to 14.0
- `Docs/SUPPORT_RUNBOOK.md` - Updated requirement to "macOS 14 Sonoma or later"
- `Docs/LANDING_PAGE_DESIGN_BRIEF.md` - Updated to "macOS 14+ required"
- `Docs/LANDING_PAGE_STRATEGIC_CONTEXT.md` - Updated all references

---

## Item 22: Graceful Undo Expiration with Archive Recovery

**Problem**: When 30-second undo window expired, user saw no indication that tabs were recoverable. Trust-breaking moment.

**Solution**: Implemented graceful expiration with archive notice:

1. **State Machine**: `UndoController` now has three states:
   - `.inactive` - No undo available
   - `.active(tabsCount)` - Undo bar showing with countdown
   - `.archived(tabsCount)` - Archive notice showing

2. **Graceful Transition**: When undo timer expires:
   - Transition to `.archived` state
   - Show toast notification: "Tabs saved to history — you can recover them anytime from Archive History"
   - Display "View Archive" bar for 5 minutes

3. **Archive Notice Bar**: After undo bar disappears, shows:
   - Archive icon
   - "Saved X tabs to history" message
   - "View Archive" button
   - Dismiss (X) button

**Files Modified**:
- `Sources/ChromeTabManager/Features/Undo/UndoController.swift` - Complete rewrite with state machine
- `Sources/ChromeTabManager/AppViewModel.swift` - Added `showArchiveNotice` property
- `Sources/ChromeTabManager/ContentView.swift` - Added `archivedUndoBar` view

**Key Code**:
```swift
enum UndoState: Equatable {
    case inactive
    case active(tabsCount: Int)
    case archived(tabsCount: Int)
}

var showArchiveNotice: Bool {
    if case .archived = state { return true }
    return false
}

private func transitionToArchived() {
    let tabsCount = lastClosedTabs.count
    state = .archived(tabsCount: tabsCount)
    // Show toast
    ToastManager.shared.showInfo("Tabs saved to history — you can recover them anytime from Archive History", duration: 8.0)
    // Schedule 5-minute notice expiration
    scheduleArchiveNoticeExpiration()
}
```

---

## Additional Fixes Applied

### BrowserAdapters Inheritance Issue

**Problem**: Swift 6 strict concurrency treating `final` classes incorrectly when inherited.

**Solution**: Removed `final` keyword from `EdgeBrowserAdapter`, `BraveBrowserAdapter`, `VivaldiBrowserAdapter`.

**Files Modified**:
- `Sources/ChromeTabManager/Managers/BrowserAdapters.swift`

### AppViewModel Broken Properties

**Problem**: References to non-existent `ScanController` properties (`scanWindowsFound`, `scanTabsFound`, `scanElapsedSeconds`).

**Solution**: Removed broken property references.

**Files Modified**:
- `Sources/ChromeTabManager/AppViewModel.swift`

---

## Verification

- **Build**: Passes
- **Tests**: 48/48 pass

---

## Files Changed Summary

| File | Changes |
|------|---------|
| `Package.swift` | macOS v14 |
| `Sources/ChromeTabManager/Managers/MenuBarController.swift` | Window activation fix |
| `Sources/ChromeTabManager/Managers/HotkeyManager.swift` | Window activation fix |
| `Sources/ChromeTabManager/Models/Session.swift` | Name collision handling |
| `Sources/ChromeTabManager/Views/SessionView.swift` | Overwrite warning UI |
| `Sources/ChromeTabManager/Stores/StatisticsStore.swift` | CSV export |
| `Sources/ChromeTabManager/Features/Undo/UndoController.swift` | Graceful expiration |
| `Sources/ChromeTabManager/AppViewModel.swift` | showArchiveNotice |
| `Sources/ChromeTabManager/ContentView.swift` | ArchivedUndoBar |
| `Sources/ChromeTabManager/Managers/BrowserAdapters.swift` | Removed final from subclasses |
| `Docs/SUPPORT_RUNBOOK.md` | Updated macOS requirement |
| `Docs/LANDING_PAGE_DESIGN_BRIEF.md` | Updated macOS requirement |
| `Docs/LANDING_PAGE_STRATEGIC_CONTEXT.md` | Updated macOS requirement |
| `Docs/EXECUTIVE_VERDICT.md` | This document |
