# Rule Preview Implementation

## Overview

Added preview functionality to the cleanup rule creation workflow, allowing users to see which tabs would be affected by a rule before saving it.

## Changes

### AutoCleanupManager.swift

Added `previewRule(_ rule: CleanupRule, against tabs: [TabInfo]) -> [TabInfo]` method:

```swift
func previewRule(_ rule: CleanupRule, against tabs: [TabInfo]) -> [TabInfo] {
    tabs.filter { rule.matches($0) }
}
```

This method takes a cleanup rule and a list of tabs, returning only the tabs that would be closed if the rule was applied.

### AddRuleSheetView.swift

Enhanced the rule creation sheet with live preview:

**New State Properties:**
- `previewTabs: [TabInfo]` - Current tabs loaded for preview
- `excludedTabIds: Set<String>` - Tabs user has chosen to exclude from preview
- `isLoadingPreview: Bool` - Loading state while fetching tabs
- `previewError: String?` - Error message if tab loading fails

**New Computed Properties:**
- `currentRule: CleanupRule?` - Builds a rule from current form inputs (name, pattern, action)
- `matchingTabs: [TabInfo]` - Tabs matching the current rule, excluding user-excluded tabs
- `previewCountText: String` - Human-readable count of affected tabs

**New UI Components:**
- `previewSection` - Shows matching tabs with domain chips
- `TabPreviewChip` - Individual tab chip showing domain with exclude toggle

**Key Features:**
1. Automatically loads all Chrome tabs when sheet opens
2. Updates preview in real-time as user types pattern
3. Shows count: "X tabs will be affected"
4. Displays tab domains as clickable chips
5. Users can exclude specific tabs from preview ("eye.slash" icon)
6. "Exclude All" button to clear all matches
7. Chips show "(excluded)" label when toggled off

**Preview Section Layout:**
```
┌─────────────────────────────────────────┐
│ Preview                          [↻]   │
├─────────────────────────────────────────┤
│ 5 tabs will be affected    [Exclude All]│
│                                                 │
│ [youtube.com] [twitter.com] [github.com] ... │
└─────────────────────────────────────────┘
```

## Usage Flow

1. User opens "Add Cleanup Rule" sheet
2. Tabs are automatically loaded from Chrome in background
3. As user enters rule name and URL pattern, preview updates
4. Matching tabs appear as orange chips
5. User can click a chip to exclude that tab from the count
6. Count text updates to reflect final impact
7. User saves rule with full awareness of impact

## Technical Details

- Preview uses `ChromeController.shared.scanAllTabsFast()` to fetch tabs
- Rule matching uses existing `CleanupRule.matches(_ tab: TabInfo)` method
- Tab exclusion is stored in-memory only (not persisted to rule)
- Error handling shows user-friendly message if Chrome is not running

## Edge Cases

- **Chrome not running**: Shows error message in preview area
- **No tabs match**: Shows "No tabs match this pattern"
- **All tabs excluded**: Count shows 0, "Exclude All" button hidden
- **Many matches (>10)**: Shows first 10 chips + "+N more" indicator

## Future Enhancements

- Persist excluded tab IDs to rule preferences
- Add "Include All" button when tabs are excluded
- Show tab titles in tooltip on chip hover
- Add search/filter within matching tabs
