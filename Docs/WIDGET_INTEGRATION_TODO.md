# Widget Integration TODO

**Date:** March 23, 2026  
**Priority:** LOW (menu bar icon provides same functionality)

---

## Status: Code Implemented, Not Integrated

### Why Not Integrated
Swift Package Manager doesn't support macOS app extension targets. Requires Xcode project.

---

## Widget Code Locations

### Widget Implementation
- `ChromeTabManagerWidgetExtension/ChromeTabManagerWidget.swift`

### Data Sharing (Ready to Wire)
- `Sources/ChromeTabManager/ViewModel+Performance.swift` - `updateWidgetDataAsync()`

---

## Integration Steps

### 1. Create Xcode Project
```bash
swift package generate-xcodeproj
# Or open in Xcode
```

### 2. Add Widget Extension Target
- File → New → Target
- Select "Widget Extension"  
- Name: ChromeTabManagerWidgetExtension
- Bundle ID: com.pranay.chrometabmanager.widget

### 3. Configure App Groups
**Main App Entitlements:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.pranay.chrometabmanager</string>
</array>
```

**Widget Entitlements:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.pranay.chrometabmanager</string>
</array>
```

### 4. Move Widget Files
- Move `ChromeTabManagerWidgetExtension/` files to Xcode widget target
- Add to widget target membership

### 5. Wire Data Sharing
- Call `updateWidgetDataAsync()` after each scan in ViewModel
- Widget reads from `UserDefaults(suiteName: "group.com.pranay.chrometabmanager")`

### 6. Test Widget
- Build widget target
- Add to Notification Center
- Verify data updates every 15 minutes

---

## Files to Modify

| File | Change |
|------|---------|
| `ChromeTabManager.entitlements` | Add app group |
| `ChromeTabManagerWidgetExtension.entitlements` | Add app group |
| `ViewModel.swift` | Call `updateWidgetDataAsync()` after scan |
| Xcode project | Add widget target |

---

## Alternative: Menu Bar Icon

Menu bar icon already provides:
- Live tab count
- Quick access
- Dropdown menu
- Always visible

**Priority: LOW** - Menu bar is more accessible than Notification Center widget.

---

## Widget Features (When Implemented)

### Small Widget
- Total tab count
- Duplicate warning indicator

### Medium Widget  
- Total tabs
- Duplicate count
- Wasted tabs
- Window count

### Data Source
```swift
struct WidgetData: Codable {
    let tabCount: Int
    let duplicateCount: Int
    let lastUpdate: Date
}
```

### Refresh
- Every 15 minutes automatically
- After each scan via `WidgetCenter.shared.reloadAllTimelines()`

---

## Export/Archive/Import Implementation

### Export Functions
Location: `ExportManager.swift`

Added export/archive/import actions:

```swift
func exportTabs(_ tabs: [TabInfo], format: ExportFormat, to url: URL) async
func exportSelectedTabs(format: ExportFormat)
func archiveTabs(_ tabs: [TabInfo], fileName: String?, format: ExportFormat, append: Bool) async
func archiveSelectedTabs(fileName: String?, format: ExportFormat, append: Bool)
func importTabs(from url: URL) async -> [ImportTab]
func openImportedTabs(_ importedTabs: [ImportTab]) async
```

Also includes widget data sharing via App Groups:
```swift
private let sharedDefaults = UserDefaults(suiteName: "group.com.pranay.chrometabmanager")
private func updateWidgetData()  // Called after each scan
```

### 4. UI Updates
Location: `Sources/ChromeTabManager/ContentView.swift`

- Export/Import menu in toolbar with format options
- File exporter for saving exports
- File importer for importing bookmarks
- Archive sheet for saving to archive location
- Import result view for reviewing imported tabs

### 5. Preferences Updates
Location: `Sources/ChromeTabManager/Preferences.swift`

Added "Export/Import" preferences tab:
- Default export format picker
- Archive location with "Open in Finder" button
- Recent archives list with open/delete actions

### 6. Widget Extension
Location: `ChromeTabManagerWidgetExtension/`

Files:
- `ChromeTabManagerWidget.swift` - Main widget implementation
- `Info.plist` - Widget extension configuration
- `ChromeTabManagerWidgetExtension.entitlements` - App group entitlement

Features:
- Small widget: Shows total tab count and duplicate warning
- Medium widget: Shows tabs, duplicates, wasted tabs, and windows
- Updates every 15 minutes
- Reads from shared UserDefaults

## Integration Steps for Xcode Project

### 1. App Group Setup

Both the main app and widget need the App Group entitlement:

**Main App Entitlements** (`ChromeTabManager.entitlements`):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.pranay.chrometabmanager</string>
</array>
```

**Widget Extension Entitlements** (`ChromeTabManagerWidgetExtension.entitlements`):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.pranay.chrometabmanager</string>
</array>
```

### 2. Xcode Project Configuration

Since this is a Swift Package Manager project, to add the widget:

1. Open the project in Xcode
2. File → New → Target
3. Select "Widget Extension"
4. Name it "ChromeTabManagerWidgetExtension"
5. Copy the contents of `ChromeTabManagerWidgetExtension/ChromeTabManagerWidget.swift` into the generated file
6. Replace the generated `Info.plist` with the one provided
7. Set the bundle identifier: `com.pranay.chrometabmanager.widget`
8. Enable App Group capability for both targets

### 3. Code Signing

Ensure both the main app and widget extension are signed with the same Team ID and have the App Group capability enabled in Xcode.

## Usage

### Exporting Tabs
1. Select tabs in the main view
2. Click Export/Import button in toolbar
3. Choose format (Bookmarks HTML, Markdown, or JSON)
4. Select save location in the file picker

### Archiving Tabs
1. Select tabs in the main view
2. Click Export/Import → Archive Selected...
3. Enter filename (or use generated timestamp)
4. Select format
5. Choose append mode (optional)
6. Click Archive

### Importing Tabs
1. Click Export/Import → Import from Bookmarks...
2. Select a Chrome bookmarks HTML file or JSON export
3. Review imported tabs in the result sheet
4. Click "Open in Chrome" to open tabs

### Widget
1. Add widget to Notification Center
2. Widget updates automatically after each scan
3. Shows tab count, duplicate count, and wasted tab count

## File Locations

- **Exports**: User-selected via save panel
- **Archives**: `~/Documents/ChromeTabManager/Archives/`
- **Imports**: User-selected via open panel

## Widget Refresh

The widget refreshes:
- Every 15 minutes automatically
- Immediately after the main app scans tabs (via `WidgetCenter.shared.reloadTimelines`)

## Data Format

### Chrome Bookmarks HTML Format
```html
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="timestamp">TabPilot Export</H3>
    <DL><p>
        <DT><A HREF="URL" ADD_DATE="timestamp">Title</A>
    </DL><p>
</DL><p>
```

### JSON Export Format
```json
{
  "exportDate": "2024-01-15T10:30:00Z",
  "totalTabs": 42,
  "tabs": [
    {
      "id": "...",
      "title": "Page Title",
      "url": "https://example.com",
      "domain": "example.com",
      "openedAt": "2024-01-15T10:00:00Z",
      "windowId": 1,
      "tabIndex": 0
    }
  ],
  "version": "1.0",
  "app": "TabPilot"
}
```

## Success Criteria Checklist

- [x] Can export tabs to Chrome bookmarks HTML format
- [x] Can export to Markdown and JSON
- [x] Can import from Chrome bookmarks HTML
- [x] Can archive tabs to file without closing
- [x] Widget shows tab count and duplicate count
- [x] Widget updates every 15 minutes
- [ ] App builds with widget extension (requires Xcode project setup)

## Notes

The widget extension requires Xcode to build properly as it needs:
1. Proper code signing with a development team
2. WidgetKit extension target configuration
3. App Group capability provisioning

The main app functionality (export/import/archive) works independently of the widget and can be built with Swift Package Manager.
