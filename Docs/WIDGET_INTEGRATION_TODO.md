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
