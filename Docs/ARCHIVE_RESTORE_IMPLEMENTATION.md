# Archive Restore Feature Implementation

**Date:** Thu Mar 26 2026  
**Status:** Implemented  
**Priority:** P0 Trust Issue

## Overview

The Archive Restore feature allows users to recover closed tabs from the archive history. Previously, users could browse archived tabs but had no way to restore them to Chrome. This implementation addresses a critical trust issue where tabs were being "saved to history" but were effectively lost.

## Changes Made

### 1. AutoArchiveManager.swift

Added `restoreTabs(_ tabs: [ArchivedTab]) async -> Int` method:

```swift
func restoreTabs(_ tabs: [ArchivedTab]) async -> Int
```

**Behavior:**
- Accepts an array of `ArchivedTab` objects
- Verifies Chrome is running before attempting restore
- Gets the current Chrome window count
- Opens each tab in window 1 (the first Chrome window)
- Returns the count of successfully opened tabs
- Logs errors appropriately via `SecureLogger`

**Error Handling:**
- Returns 0 if Chrome is not running
- Returns 0 if no windows are available
- Individual tab failures don't stop the overall restore process

### 2. ArchiveHistoryView.swift

**Changes:**
- Added "Restore This Date" button (down arrow icon) next to each archive entry
- Added `restoreArchive(_ archive: ArchiveEntry)` method
- Restoring from history view opens all tabs from that date

**UI Elements:**
- Restore button with `arrow.down.to.line` SF Symbol
- Blue foreground color to indicate interactivity
- Tooltip: "Restore all tabs from this date"

### 3. ArchiveDetailView.swift

Complete rewrite with selection and restore functionality:

**New State:**
- `selectedTabs: Set<String>` - tracks selected tab IDs
- `isRestoring: Bool` - prevents double-restore during operation

**UI Elements:**
- **Checkbox column:** Click to select/deselect individual tabs
- **Select All checkbox:** Toggle select all tabs
- **Selection counter:** Shows "X selected" label
- **Restore Selected button:** Opens only selected tabs (disabled when none selected)
- **Restore All button:** Opens all tabs from the archive

**Behavior:**
- "Restore Selected" only enabled when at least one tab is selected
- Both buttons show a `ProgressView` while restore is in progress
- On success, displays success toast and dismisses the sheet
- Toast message shows: "Restored X tabs"

## Architecture

### Data Flow

```
User taps "Restore" 
    → ArchiveDetailView.restoreAll/restoreSelected()
    → AutoArchiveManager.restoreTabs(tabs)
    → ChromeController.shared.openTab(windowId: 1, url: tab.url)
    → AppleScript to open tab in Chrome
    → Returns count of successful opens
    → ToastManager shows success message
```

### Toast Notifications

Uses `ToastManager.shared.show()` with `.success` type:
- Archive history restore: "Restored X tabs from [date]"
- Archive detail restore: "Restored X tabs"

## Dependencies

- `ChromeController.shared.openTab()` - AppleScript-based tab opening
- `ChromeController.shared.isChromeRunning()` - Pre-flight check
- `ChromeController.shared.getWindowCount()` - Verify windows exist
- `ToastManager.shared.show()` - User feedback

## Testing Considerations

1. **Chrome running:** Verify error handling when Chrome is not running
2. **No windows:** Verify behavior when Chrome has no open windows
3. **Partial failures:** Some tabs may fail to open (invalid URLs, etc.)
4. **Large archives:** Restoring many tabs at once should work reliably

## Future Enhancements

1. **Progress indicator:** Show progress when restoring large numbers of tabs
2. **Cancel operation:** Allow canceling a restore in progress
3. **Specific window selection:** Let user choose which window to restore to
4. **Dedicated window:** Optionally restore to a new Chrome window
