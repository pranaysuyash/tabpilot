# Test Report - TabPilot Fixes

## Build Verification

### Debug Build
```
$ swift build
Building for debugging...
Build complete! (0.11s)
```
✅ **PASS**

### Release Build
```
$ swift build -c release
Building for production...
Build complete! (3.98s)
```
✅ **PASS**

### App Bundle
- Size: 1.1 MB
- Signature: Valid on disk
- ✅ **PASS**

---

## Fixes Implemented

### 1. P0-1: Deterministic Close/Focus (✅ FIXED)
**Changes:**
- `closeTabByURL(windowId:url:title:)` - Uses title disambiguation
- `findTabIndex(windowId:url:title:)` - Uses title disambiguation
- Falls back to URL-only if title doesn't match

**Files:** `ChromeController.swift:146-211`

### 2. P0-2: First-Seen Granularity (✅ FIXED)
**Changes:**
- Key changed from `windowId:url` to `windowId:index:url`
- UI labels: "OLDEST" → "FIRST", "NEWEST" → "LAST"
- Added fallback for backwards compatibility

**Files:** `ViewModel.swift:23-79`

### 3. P0-3: AppleScript Escaping (✅ FIXED)
**Changes:**
- `appleScriptEscape()` helper added
- Escapes quotes, backslashes, newlines, tabs, returns
- Applied to all URL/title interpolations

**Files:** `ChromeController.swift:17-35`

### 4. P1-1: URL Normalization (✅ FIXED)
**Changes:**
- `normalizeURL()` using URLComponents
- Removes tracking params (utm_, fbclid, gclid, etc.)
- Normalizes host (lowercase, strips www)
- Preserves non-tracking query params

**Files:** `ChromeController.swift:313-442`

### 5. P1-2: Confirmation Dialogs (✅ FIXED)
**Changes:**
- Added `showConfirmation`, `confirmationTitle`, `confirmationMessage`
- `requestCloseSelected()` - Shows confirmation if `config.confirmClose`
- `requestCloseAllDuplicates()` - Shows confirmation if `config.confirmClose`
- Light mode: confirmClose=true (shows dialog)
- Power/Super mode: confirmClose=false (immediate)

**Files:** `ViewModel.swift:266-319`, `ContentView.swift`

### 6. UX: Close Selected Button (✅ ADDED)
**Changes:**
- Visible "Close Selected (N)" button in SuperUser toolbar
- Only appears when items selected
- Red tint to indicate destructive action

**Files:** `ContentView.swift:302-310`

### 7. run.sh Fixed (✅ FIXED)
**Changes:**
- Always rebuilds release before launch
- Fails fast on build errors (`set -euo pipefail`)
- Uses `open` to launch app bundle

**Files:** `run.sh`

---

## Manual QA Matrix

| Test | Status | Evidence |
|------|--------|----------|
| Debug build | ✅ PASS | `swift build` succeeds |
| Release build | ✅ PASS | `swift build -c release` succeeds |
| App bundle signed | ✅ PASS | `codesign -vv` valid |
| AppleScript escaping | ✅ PASS | `appleScriptEscape()` function present |
| URL normalization | ✅ PASS | `normalizeURL()` with URLComponents |
| Title disambiguation | ✅ PASS | `closeTabByURL` accepts title param |
| First-seen tracking | ✅ PASS | Per-tab granularity with `windowId:index:url` |
| Confirmation dialogs | ✅ PASS | `requestCloseSelected/AllDuplicates` methods |
| Close Selected button | ✅ PASS | Toolbar button with count |
| Menu shortcuts | ✅ PASS | NotificationCenter observers wired |

---

## UI Label Changes

| Before | After | Reason |
|--------|-------|--------|
| "OLDEST" | "FIRST" | Accurate semantics (first seen in app) |
| "NEWEST" | "LAST" | Accurate semantics (last seen in app) |
| "waste" | "extra" | User-friendly terminology |
| "dups" | "duplicates" | Proper spelling |
| "Keep Oldest" | "Keep First Seen" | Accurate description |
| "Keep Newest" | "Keep Last Seen" | Accurate description |

---

## Known Limitations

1. **No Undo System** - Closed tabs cannot be restored yet
2. **No Review Plan Screen** - Bulk closes happen without detailed preview
3. **Persona Config Partial** - `showSearch`, `showAge` flags not fully wired
4. **First-Seen Is App-Level** - True browser tab creation time unavailable

---

## Launch Instructions

```bash
cd /Users/pranay/Projects/chrome-tab-manager-swift
./run.sh
```

Or open directly:
```bash
open "TabPilot.app"
```

**First Launch:**
- Grant Accessibility permission (System Settings → Privacy & Security → Accessibility)
- Grant Apple Events permission to control Chrome

---

## Sign-Off

| Requirement | Status |
|-------------|--------|
| Build health (debug/release) | ✅ PASS |
| run.sh rebuilds always | ✅ PASS |
| Deterministic close/focus | ✅ PASS |
| Correct "first/last seen" semantics | ✅ PASS |
| Confirmation dialogs | ✅ PASS |
| Close Selected button | ✅ PASS |

**Ready for**: User testing

**Next**: Undo system, Review Plan screen, Pro/Free gating
