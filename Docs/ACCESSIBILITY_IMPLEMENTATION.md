# Accessibility Implementation Guide

## Overview
This document details the comprehensive keyboard navigation and VoiceOver accessibility implementation for TabPilot.

## Keyboard Navigation

### Global Shortcuts (Work everywhere)
- **⌘ + Shift + C**: Scan tabs (global hotkey, works even when app is backgrounded)
- **⌘ + Shift + D**: Close duplicates (global hotkey)

### App Menu Shortcuts (Tabs menu)
- **⌘ + S**: Scan tabs
- **⌘ + ⇧ + R**: Refresh tabs
- **⌘ + Shift + P**: Review cleanup plan
- **⌘ + Shift + S**: Smart select tabs
- **⌘ + Delete**: Close selected tabs
- **⌘ + F**: Focus filter/search field
- **⌘ + ?**: Show keyboard shortcuts help

### Navigation Keys (Within lists/tables)
- **Tab**: Move focus to next section
- **Shift + Tab**: Move focus to previous section
- **↑ / ↓**: Navigate items in current list
- **Home**: Jump to first item
- **End**: Jump to last item

### Action Keys
- **Space**: Select/deselect current item
- **Return**: Activate current item (focus tab in Chrome)
- **⌘ + Return**: Close current duplicate group

### View Shortcuts
- **⌘ + T**: Toggle table/list view (when in SuperUser mode)

## VoiceOver Support

### Table View (SuperUserTableView)
Each row announces:
- Title of the tab
- Domain name
- Number of duplicates
- Selection state (selected/not selected)
- Position (e.g., "3 of 10")

Example: "GitHub, github.com, 3 duplicates, selected, 2 of 15"

### List View (StandardUserView)
- Each duplicate group is a separate accessibility element
- Announces group title and duplicate count
- Action buttons have descriptive labels

### Sidebar
- Window list items announce window ID and tab count
- Persona card announces user type and description
- Tab health score announced with context

### Notifications
- Focus changes announced (e.g., "Sidebar", "Toolbar", "Table view")
- View mode changes announced (e.g., "Switched to table view")
- Selection changes announced (e.g., "Selected 3 tabs", "Deselected 3 tabs")

## Implementation Details

### Files Added/Modified
1. **KeyboardNavigationManager.swift**: Central keyboard navigation management
2. **SuperUserTableView.swift**: Enhanced with full keyboard support
3. **ChromeTabManager.swift**: Menu shortcuts integration
4. **ContentView.swift**: Help sheet presentation
5. **MainContentView.swift**: Toggle view notification handler

### Key Components

#### KeyboardNavigationManager
- Singleton managing focus state
- NavigationFocus enum for different sections
- AccessibilityNotification enum for VoiceOver announcements

#### AccessibilityNotification
Posts announcements to VoiceOver using NSAccessibility API:
- `.announcement`: General announcements
- `.layoutChanged`: Layout changes
- `.screenChanged`: Screen changes

#### KeyboardShortcutsHelpView
Comprehensive help sheet showing all 18 keyboard shortcuts organized by category.

## Testing Keyboard Navigation

### Full Workflow Test
1. Press ⌘ + S to scan
2. Press Tab to navigate to list/table
3. Use ↑/↓ to navigate items
4. Press Space to select tabs
5. Press ⌘ + Shift + P to review
6. Press ⌘ + Delete to close
7. Press ⌘ + ? to view shortcuts

### VoiceOver Test
1. Enable VoiceOver (⌘ + F5)
2. Navigate to table/list
3. Use VO + →/← to navigate rows
4. Verify announcements include all context
5. Test selection state changes

## Power User Features

### Complete Trackpad-Free Workflow
1. **Scan**: ⌘ + S
2. **Refresh**: ⌘ + ⇧ + R
3. **Navigate**: Tab, then ↑/↓
4. **Select**: Space
5. **Review**: ⌘ + Shift + P
6. **Close**: ⌘ + Delete
7. **Undo**: Available in toast notification

### Efficiency Tips
- Use ⌘ + F to quickly filter without mouse
- Use ⌘ + T to toggle between table (dense) and list (detailed) views
- Use ⌘ + Return on any group to close all duplicates in that group
- Global hotkeys (⌘ + Shift + C/D) work from any app

## Accessibility Compliance

### WCAG 2.1 Level AA
- ✓ Keyboard accessible (2.1.1)
- ✓ No keyboard traps (2.1.2)
- ✓ Focus visible (2.4.7)
- ✓ Focus order logical (2.4.3)
- ✓ Labels and instructions (3.3.2)
- ✓ Status messages announced (4.1.3)

### macOS Specific
- ✓ Full VoiceOver support
- ✓ Reduced motion support (via .animation modifiers)
- ✓ High contrast support (system colors)
- ✓ Full keyboard access mode compatible

## Future Enhancements

### Potential Additions
1. Customizable keyboard shortcuts
2. Voice commands (Siri Shortcuts)
3. Switch Control support
4. Full screen reader optimization
5. Audio cues for actions

## Notes

- All keyboard shortcuts use standard macOS conventions
- VoiceOver announcements respect user verbosity settings
- Focus indicators are visible but subtle to not distract visual users
- Global hotkeys require accessibility permission (prompted on first use)
