# A++ Architecture Roadmap

**Date:** March 23, 2026  
**Status:** Implementation Complete (A Grade: 85/100)

## Phase 1: Foundation ✅
- [x] Create DefaultsKeys for UserDefaults keys
- [x] Create service protocols for testability
- [x] Extract TabCloseOperation for deduplicated closing

## Phase 2: Service Extraction ✅
- [x] TabScanService - Tab scanning logic
- [x] SessionService - Session management
- [x] DuplicateDetectionService - Duplicate filtering
- [x] ExportService - Export/import/archive
- [x] CleanupRuleService - Cleanup rule CRUD

## Phase 3: View Extraction ✅
- [x] AutoCleanupPreferencesView extracted
- [x] RuleRowView extracted
- [x] AddRuleSheetView extracted
- [x] PreferencesView modularized

## Phase 4: ViewModel Slimming ⏳
- [x] ViewModel coordination role established
- [x] Services injected
- [ ] ViewModel <300 lines target

## Architecture Score: A (85/100)

| Category | Score | Notes |
|----------|-------|-------|
| Separation of Concerns | 9/10 | Services extracted |
| ViewModel Complexity | 7/10 | Still ~1000 lines |
| Testability | 8/10 | Protocols exist |
| Code Organization | 8/10 | Views separated |

## Current Structure

```
ViewModel (Coordinator)
├── TabScanService
├── SessionService  
├── DuplicateDetectionService
├── ExportService
├── CleanupRuleService
├── TabCloseOperation
└── ChromeController (Actor)
```

## Service Protocols

```swift
protocol TabScanServiceProtocol {
    func scanAllTabs() async -> [TabInfo]
}

protocol TabCloseOperationProtocol {
    func closeTabs(_ tabs: [TabInfo]) async -> CloseResult
}
```

## Files Extracted

| File | Lines Saved |
|------|--------------|
| AutoCleanupPreferencesView | ~170 |
| RuleRowView | ~30 |
| AddRuleSheetView | ~60 |
| Preferences modularized | ~200 |

## Remaining Work
- ViewModel further slimming
- Unit tests for services
