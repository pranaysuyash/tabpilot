# Build Audit - Missing API Implementations

**Date:** 2026-03-23
**Status:** In Progress - Structural Issues Detected

---

## Overview
Tracking missing ViewModel APIs and build errors.

**Current Error Count:** 68 errors

---

## Phase 1 Status: ✅ ViewModel Additions Complete

The following APIs have been added to ViewModel.swift:

| API | Status |
|-----|--------|
| `openTab(windowId:url:)` | ✅ Added |
| `openTabs(_:)` | ✅ Added |
| `domainGroups` | ✅ Added |
| `pruningCandidates` | ✅ Added |
| `closeTabsInDomain(_:)` | ✅ Added |
| `urlPatterns` | ✅ Added |
| `addURLPattern(_:)` | ✅ Added |
| `checkURLPatterns(for:)` | ✅ Added |
| `ExportFormat` enum | ✅ Added |
| `exportFormat` | ✅ Added |
| `sessions` | ✅ Added |
| `cleanupRules` | ✅ Added |
| `loadCleanupRules()` | ✅ Added |
| `healthMetrics` | ✅ Added |
| `showArchiveHistory` | ✅ Added |
| `closedTabHistory` | ✅ Added |
| `moveTabsToWindow(tabIds:targetWindowId:)` | ✅ Added (stub) |
| `moveTabsToNewWindow(tabIds:)` | ✅ Added (stub) |
| `displayToast(message:)` | ✅ Added (was private, now public) |

---

## Phase 2 Status: ✅ LicenseManager Fixed

- Added `isPro` computed property: `var isPro: Bool { isLicensed }`
- Fixed structural issues in Licensing.swift (missing init brace)
- `PaywallCopy` struct is now present in Licensing.swift

---

## Phase 3 Status: ⚠️ ContentView.swift Has Duplicates

**Issue:** ContentView.swift contains view struct definitions that are also defined in separate view files:

| Duplicate View | Location in ContentView | Should be in |
|---------------|------------------------|--------------|
| `ToastView` | Line 84 | ComponentViews.swift |
| `SidebarView` | Line 109 | Separate SidebarView file |
| `PersonaCard` | Line 137 | Separate PersonaView file |
| `ScanningCard` | Line 190 | ComponentViews.swift |
| `WelcomeCard` | Line 207 | ComponentViews.swift |
| `MainContentView` | Line 223 | Separate file |
| `LightUserView` | Line 249 | Separate PersonaViews file |
| `SuperUserView` | Line 325 | Separate PersonaViews file |
| `StandardUserView` | Line 439 | Separate PersonaViews file |
| `BigStat` | Line 480 | ComponentViews.swift |
| `SimpleDuplicateRow` | Line 497 | ComponentViews.swift |
| `SuperDuplicateRow` | Line 526 | ComponentViews.swift |
| `ScanningView` | Line 586 | ComponentViews.swift |
| `EmptyStateView` | Line 603 | ComponentViews.swift |
| `DuplicateGroupSection` | Line 625 | Separate file |
| `StatBadge` | Line 694 | ComponentViews.swift |
| `ActionButton` | Line 745 | ComponentViews.swift |
| `TabRow` | Line 768 | ComponentViews.swift |
| `AppToolbarContent` | Line 840 | Separate file |
| `viewModeShortcut(for:)` | Line 866 | Helper, OK in ContentView |
| `ReviewPlanView` | Line 877 | ReviewPlanView.swift |
| `ReviewPlanItemRow` | Line 931 | ReviewPlanView.swift |
| `PaywallView` | Line 979 | PaywallView.swift |
| `StatBadge` | Line 694 | ComponentViews.swift |

---

## Phase 4 Status: ❌ Build Verification Needed

### Errors by Category

| Category | Count | Notes |
|----------|-------|-------|
| Duplicate view declarations | ~25 | ContentView vs view files |
| macOS version availability | ~10 | `onChange(of:initial:_:)` requires macOS 14 |
| SwiftData issues | ~5 | ModelContext availability |
| Missing methods/properties | ~20 | Various managers need updates |
| Other | ~8 | Misc issues |

---

## Structural Issues Requiring Resolution

### 1. Duplicate View Declarations
ContentView.swift contains views that exist elsewhere. Options:
- **Option A:** Remove duplicates from ContentView.swift and rely on separate files
- **Option B:** Keep all views in ContentView.swift and delete separate files
- **Option C:** Create proper module imports

### 2. macOS Version Compatibility
Several views use `onChange(of:initial:_:)` which requires macOS 14+:
- AutoCleanupPreferencesView.swift
- ExportView.swift

### 3. SwiftData Dependencies
- AutoCleanupManager.swift uses ModelContext (macOS 14+)
- CleanupRuleStore.swift uses ModelContext (macOS 14+)

---

## Missing Models Added

✅ Added to Models.swift:
- `DomainGroup` struct
- `HealthMetrics` struct with `compute(from:duplicates:)` static method

---

## Verification Command

```bash
swift build -c release 2>&1 | grep "error:" | wc -l
```

**Target:** 0 errors
**Current:** 68 errors

---

## Next Steps

1. **Decision needed:** How to handle duplicate views in ContentView.swift?
2. **macOS compatibility:** Add `#available` checks or update minimum target to macOS 14
3. **SwiftData:** Either update minimum target or refactor CleanupRuleStore to not use SwiftData
4. **Build verification:** After fixing above, run final build

---

## Files Requiring Attention

| File | Issues |
|------|--------|
| ContentView.swift | ~25 duplicate view declarations |
| AutoCleanupPreferencesView.swift | onChange availability (macOS 14) |
| ExportView.swift | onChange availability (macOS 14) |
| AutoCleanupManager.swift | SwiftData, missing try, missing DefaultsKeys |
| CleanupRuleStore.swift | SwiftData ModelContext |
| Views/PaywallView.swift | Duplicate PaywallView |
| Views/ReviewPlanView.swift | Duplicate ReviewPlanView |

---

*Last Updated: 2026-03-23*
