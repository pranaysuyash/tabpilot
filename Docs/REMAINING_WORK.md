# Remaining Work - Chrome Tab Manager

## ✅ COMPLETED (Production Ready)

### Critical (P0)
- [x] Build passes (debug & release)
- [x] Tests exist and pass (11/11)
- [x] run.sh fixed and executable
- [x] Single-call bulk scan (major performance improvement)
- [x] Deterministic close with index resolution
- [x] Menu/UI path parity for close operations
- [x] Preferences dismissible (Done button + Esc)
- [x] AppleScript escaping
- [x] URL normalization
- [x] Undo gating by license tier
- [x] Protected domains enforcement
- [x] Free tier close accounting
- [x] Copy polish (removed jargon)

## ⏳ REMAINING WORK

### P1: Important (Should Fix Before Release)

#### 1. Real StoreKit Integration
**Current**: DEBUG mode auto-grants Pro license
**Needed**: Actual App Store Connect integration
**Files**: `Licensing.swift`
**Complexity**: Medium (requires Apple Developer account)

#### 2. Error Telemetry in UI
**Current**: Failures tracked but not displayed to user
**Needed**: Show scan failures, windows failed, tabs failed
**Files**: `ChromeController.swift`, `ContentView.swift`
**Complexity**: Low

#### 3. Memory Optimization
**Current**: Full timestamp JSON saved on every scan
**Needed**: Delta updates, debounced saves
**Files**: `ViewModel.swift`
**Complexity**: Low

#### 4. View Caching
**Current**: `filteredDuplicates` computed on every access
**Needed**: Cache derived views after scan
**Files**: `ViewModel.swift`
**Complexity**: Low

#### 5. Multi-Window Safety
**Current**: `WindowGroup` can spawn multiple windows
**Risk**: Command duplication across windows
**Fix**: Use `Window` scene instead
**Files**: `ChromeTabManager.swift`
**Complexity**: Low

### P2: Nice to Have (Post-Release)

#### 6. Table View for Super-User Mode
**Current**: List view even for 4k tabs
**Better**: Table with sortable columns (Title, Domain, Window, Count, Age)
**Files**: `ContentView.swift`
**Complexity**: Medium

#### 7. Close Batching Optimization
**Current**: Sequential close with 50ms sleeps
**Better**: Batch close by window, parallel window processing
**Files**: `ChromeController.swift`
**Complexity**: Medium

#### 8. Animation Polish
**Current**: Basic transitions
**Better**: Coordinated animations, row removal effects
**Files**: `ContentView.swift`
**Complexity**: Low

#### 9. Window Activation
**Current**: `ignoringOtherApps: true` forces activation
**Better**: Respect user context, activate only on explicit reopen
**Files**: `ChromeTabManager.swift`
**Complexity**: Low

### P3: Future Features

#### 10. Tab Debt Score
**Description**: Health metric with trends over time
**Complexity**: Medium

#### 11. Scheduled Cleanup
**Description**: Background reminders, automated cleanup rules
**Complexity**: High

#### 12. Cross-Browser Support
**Description**: Arc, Edge, Brave support
**Complexity**: High

## Go-Live Checklist

### Must Have (Block Launch)
- [ ] Real StoreKit integration OR remove paywall (ship free only)
- [ ] App Store screenshots
- [ ] Privacy policy
- [ ] App Store description

### Should Have (Strongly Recommended)
- [ ] Error telemetry in UI
- [ ] Multi-window safety fix
- [ ] Memory optimization

### Nice to Have (Can Ship Without)
- [ ] Table view
- [ ] Animation polish
- [ ] Tab debt score

## Recommendation

**Current State**: MVP is feature-complete and stable
**Blockers for App Store**:
1. Decide: Real StoreKit vs Free-only vs Delayed paywall
2. Basic error telemetry (1-2 hours work)

**ETA to Ship**: 
- With StoreKit: 1-2 weeks (Apple review + integration)
- Free-only: 2-3 days (screenshots + metadata)

## Testing Status

| Component | Status |
|-----------|--------|
| Unit tests | ✅ 11/11 pass |
| Build | ✅ Debug & release |
| Launch script | ✅ Working |
| Performance | ✅ Single-call scan |
| Safety | ✅ Gating verified |
| UX | ✅ Tooltips, help text |

## Files Overview

```
Sources/ChromeTabManager/
├── ChromeController.swift    # AppleScript, scan, close
├── ChromeTabManager.swift    # App entry, menu commands
├── ContentView.swift         # UI (sidebar, views, review plan)
├── Licensing.swift           # Free/Pro tiers (StoreKit TODO)
├── Models.swift              # Data models
├── PersonaDetection.swift    # User personas
├── Preferences.swift         # Settings UI
└── ViewModel.swift           # State management

Tests/ChromeTabManagerTests/
└── ChromeTabManagerTests.swift  # 11 unit tests
```

## Next Actions

1. **Immediate**: Test with real Chrome (158 windows)
2. **This week**: Add error telemetry UI
3. **Decision**: StoreKit integration vs free-only launch
4. **Next**: App Store Connect setup (if paid)
