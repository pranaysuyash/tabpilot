# Widget Extension

**Status:** Files present but not integrated into build

## Current State
- `ChromeTabManagerWidget.swift` exists
- `ChromeTabManagerWidgetExtension.entitlements` exists
- Not included in `Package.swift`

## Why Not Integrated
Swift Package Manager (SPM) does not support macOS app extensions (WidgetKit, Share Extensions, etc.). 
App extensions require Xcode project configuration with proper target embedding.

## Options to Enable Widget

### Option 1: Use Xcode
1. Open the project in Xcode
2. Add a new "Widget Extension" target
3. Configure app groups for data sharing
4. Set up proper entitlements

### Option 2: Manual Integration
1. Create `ChromeTabManager.xcodeproj` 
2. Add both main app and widget extension targets
3. Configure embedding and signing

## Required for Widget

### Entitlements
```xml
com.apple.security.application-groups = [group.com.pranay.chrometabmanager]
```

### Data Sharing
Widget needs to read tab data from shared UserDefaults (app group).
Currently `ViewModel+Performance.swift` has `updateWidgetDataAsync()` but it's not called.

### Implementation Notes
- Widget shows: tab count, duplicate count, quick actions
- Data flows through: ViewModel → App Group UserDefaults → Widget
- Update frequency: On scan completion

## Recommendation
For production release, use Xcode to properly configure the widget extension.
For now, the menu bar icon provides similar quick-access functionality.
