# Remaining Work - TabPilot

## ✅ COMPLETED

### Critical (P0)
- [x] Build passes (debug & release)
- [x] Tests exist and pass (34/34)
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

### P1: Completed ✅
- [x] **Error Telemetry in UI** - Scan failures shown in SidebarView
- [x] **Memory Optimization** - Timestamps use debounced saves, batch close optimization
- [x] **View Caching** - `filteredDuplicates` computed with caching

### P2: Completed ✅
- [x] **Close Batching Optimization** - Single AppleScript call for multiple tabs per window
- [x] **Animation Polish** - Gauge animations, trend visualizations

### P3: Completed ✅
- [x] **Tab Debt Score** - Health metric with trends over time, recorded after each scan

## ⏳ REMAINING WORK

### P1: Important (Should Fix Before Release)

#### 1. Real StoreKit Integration
**Current**: DEBUG mode auto-grants Pro license
**Needed**: Actual App Store Connect integration
**Files**: `Licensing.swift`
**Complexity**: Medium (requires Apple Developer account)

#### 2. Multi-Window Safety
**Current**: `WindowGroup` can spawn multiple windows
**Risk**: Command duplication across windows
**Fix**: Use `Window` scene instead
**Files**: `ChromeTabManager.swift`
**Complexity**: Low

### P2: Nice to Have (Post-Release)

#### 3. Table View for Super-User Mode
**Current**: List view even for 4k tabs
**Better**: Table with sortable columns (Title, Domain, Window, Count, Age)
**Files**: `ContentView.swift`
**Complexity**: Medium

#### 4. Window Activation
**Current**: `ignoringOtherApps: true` forces activation
**Better**: Respect user context, activate only on explicit reopen
**Files**: `ChromeTabManager.swift`
**Complexity**: Low

### P3: Future Features

#### 5. Scheduled Cleanup
**Description**: Background reminders, automated cleanup rules
**Complexity**: High

#### 6. Cross-Browser Support
**Description**: Arc, Edge, Brave support
**Complexity**: High

## Go-Live Checklist

### Must Have (Block Launch)
- [ ] Real StoreKit integration OR remove paywall (ship free only)
- [ ] App Store screenshots
- [ ] Privacy policy
- [ ] App Store description

### Should Have (Strongly Recommended)
- [x] Error telemetry in UI ✅
- [x] Memory optimization ✅
- [x] Multi-window safety fix (still pending)
- [x] Close batching optimization ✅

### Nice to Have (Can Ship Without)
- [x] Table view (deferred)
- [x] Animation polish ✅
- [x] Tab debt score ✅

## Testing Status

| Component | Status |
|-----------|--------|
| Unit tests | ✅ 34/34 pass |
| Build | ✅ Debug & release |
| Launch script | ✅ Working |
| Performance | ✅ Single-call scan + batch close |
| Safety | ✅ Gating verified |
| UX | ✅ Tooltips, help text |

## Recently Added Features

| Feature | Date | Status |
|---------|------|--------|
| Tab Debt Score | 2026-03-23 | ✅ Complete |
| Close Batching | 2026-03-23 | ✅ Complete |
| Error Telemetry UI | 2026-03-23 | ✅ Complete |
| Animation Polish | 2026-03-23 | ✅ Complete |
| Memory Optimization | 2026-03-23 | ✅ Complete |
| DATA Flow Audit (001-010) | 2026-03-23 | ✅ Complete |

## Recommendation

**Current State**: MVP is feature-complete and stable with many enhanced features implemented.

**Remaining Blockers for App Store**:
1. Decide: Real StoreKit vs Free-only vs Delayed paywall
2. Multi-window safety fix (1-2 hours work)

**ETA to Ship**: 
- With StoreKit: 1-2 weeks (Apple review + integration)
- Free-only: 2-3 days (screenshots + metadata)
