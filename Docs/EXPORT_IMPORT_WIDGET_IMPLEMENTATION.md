# Export/Import/Archive + Widget Integration

Date: 2026-03-23

## Implemented

### ViewModel APIs
Location: `Sources/ChromeTabManager/ViewModel.swift`

Implemented file-based export/import/archive flows:

- `func exportTabs(_ tabs: [TabInfo], format: ExportFormat, to url: URL) async`
- `func exportSelectedTabs(format: ExportFormat)`
- `func archiveTabs(_ tabs: [TabInfo], fileName: String?, format: ExportFormat, append: Bool) async`
- `func archiveSelectedTabs(fileName: String?, format: ExportFormat, append: Bool)`
- `func importTabs(from url: URL) async -> [ImportTab]`
- `func openImportedTabs(_ importedTabs: [ImportTab]) async`

Additional support:
- JSON export format with metadata (`exportDate`, `version`, `app`, `tabs`)
- Chrome Bookmarks HTML export format
- HTML bookmarks parser and JSON parser for imports
- Archive directory selection + recent archives persistence

### Widget data sharing (App Group)
Location: `Sources/ChromeTabManager/ViewModel.swift`

- `private let sharedDefaults = UserDefaults(suiteName: "group.com.pranay.chrometabmanager")`
- `private func updateWidgetData()`
- Called after each successful scan to push:
  - total tabs
  - duplicate groups
  - wasted tabs
  - window count
  - last updated timestamp
- Triggers timeline reload via `WidgetCenter.shared.reloadAllTimelines()` when WidgetKit is available.

### UI updates
Location: `Sources/ChromeTabManager/ContentView.swift`

Added:
- Toolbar `Export/Import` menu
- Export Selected by format
- Archive Selected sheet
- File exporter save flow
- File importer open flow
- Import result review sheet with "Open in Chrome"

### Preferences updates
Location: `Sources/ChromeTabManager/Preferences.swift`

Added `Export/Import` preferences tab:
- Default export format picker
- Archive location chooser
- Open archive folder in Finder
- Recent archives with open/delete actions

### New model
Location: `Sources/ChromeTabManager/Models.swift`

- `ImportTab` for import preview/open flow.

### Defaults keys
Location: `Sources/ChromeTabManager/Utilities/DefaultsKeys.swift`

Added:
- `defaultExportFormat`
- `archiveLocationPath`
- `recentArchivePaths`

## Widget Extension Scaffold

Created folder: `ChromeTabManagerWidgetExtension/`

Files:
- `ChromeTabManagerWidget.swift`
- `Info.plist`
- `ChromeTabManagerWidgetExtension.entitlements`

Main app entitlement added:
- `ChromeTabManager.entitlements`

Widget behavior:
- Small: total tabs + duplicate warning
- Medium: tabs, dupes, wasted tabs, windows
- Refresh policy: every 15 minutes

## Xcode Integration Required

This repository is SwiftPM-based. Widget target must be added in Xcode:

1. Open project in Xcode
2. File -> New -> Target -> Widget Extension
3. Name target `ChromeTabManagerWidgetExtension`
4. Bundle ID: `com.pranay.chrometabmanager.widget`
5. Add `ChromeTabManagerWidgetExtension/*` files to widget target
6. Enable App Group capability on both app + widget targets:
   - `group.com.pranay.chrometabmanager`
7. Ensure both targets use same Team ID

## Usage

### Export selected tabs
1. Select tabs
2. Toolbar -> Export/Import -> Export Selected
3. Pick format and save

### Archive selected tabs
1. Select tabs
2. Toolbar -> Export/Import -> Archive Selected
3. Set file name/format/append
4. Archive to configured archive directory

### Import tabs
1. Toolbar -> Export/Import -> Import from Bookmarks
2. Pick bookmarks HTML or JSON
3. Review import result
4. Click "Open in Chrome"

## Build/Test status

Verified:
- `swift build` passes
- `swift test` passes

Note: widget target compilation requires Xcode target configuration and signing.
