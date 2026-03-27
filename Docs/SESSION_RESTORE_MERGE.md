# Session Restore Merge Options

## Overview

This document describes the implementation of session restore merge options in Chrome Tab Manager. When restoring a session, users now have control over how the session tabs are merged with their currently open Chrome tabs.

## Problem

Previously, when restoring a session, ALL session tabs were opened in Chrome with no options. If the user had 20 tabs open and restored a 30-tab session, they would end up with 50 tabs - potentially overwhelming.

## Solution

Added three restore options that give users control over how sessions are restored:

### RestoreOptions Enum

```swift
enum RestoreOptions: String, CaseIterable, Identifiable {
    case addToOpen = "Add to Open"
    case newWindow = "New Window"
    case replaceOpen = "Replace Open"
}
```

**Options:**

1. **Add to Open** (Default)
   - Adds tabs to existing Chrome tabs
   - Safest option - no existing tabs are closed
   - Use case: Preserving current workflow while adding session tabs

2. **New Window**
   - Opens session in a new Chrome window
   - Existing tabs remain untouched
   - Use case: Keeping separate contexts open simultaneously

3. **Replace Open**
   - Closes all currently open Chrome tabs first, then opens session
   - Destructive option - shows warning before proceeding
   - Use case: Starting fresh with only the session tabs

## Implementation Details

### Files Modified

1. **Sources/ChromeTabManager/Models/Session.swift**
   - Added `RestoreOptions` enum
   - Added `restoreSession(_ session: Session, option: RestoreOptions) async -> Int` method to `SessionStore`

2. **Sources/ChromeTabManager/ChromeController.swift**
   - Added `createNewWindow() async -> Int?` - Creates a new Chrome window and returns its ID
   - Added `closeAllTabs() async -> Bool` - Closes all tabs in all Chrome windows

3. **Sources/ChromeTabManager/Views/SessionView.swift**
   - Added state variables: `sessionToRestore` and `showRestoreOptions`
   - Added `RestoreOptionsSheet` view with UI for selecting restore option
   - Updated `SessionRow` to use `onRestore` callback instead of direct restore

### User Flow

1. User clicks restore button on a session row
2. `RestoreOptionsSheet` appears as a sheet
3. User selects an option:
   - **Add to Open**: Opens tabs directly in existing windows (default)
   - **New Window**: Creates new window first, then opens tabs
   - **Replace Open**: Shows warning, closes all tabs, then opens session
4. Session is restored with the selected option
5. `markOpened()` is called to update last opened timestamp

### UI Design

The `RestoreOptionsSheet` includes:
- Session name and tab count display
- Radio-button style option selection
- Icon for each option (plus.circle, rectangle.portrait.on.rectangle.portrait.angled, arrow.triangle.2.circlepath)
- Descriptive text for each option
- Warning banner for destructive "Replace Open" option
- Cancel and Restore buttons
- Keyboard shortcuts (Escape to cancel, Enter/Return to restore)

## Error Handling

All AppleScript operations include error handling:
- `createNewWindow()` returns `nil` on failure, logs error
- `closeAllTabs()` returns `false` on failure, logs error
- `restoreSession()` continues attempting to open remaining tabs if individual tabs fail
- Returns count of successfully opened tabs

## Backwards Compatibility

The default option `addToOpen` maintains the same behavior as the previous implementation, ensuring existing users don't experience unexpected behavior.
