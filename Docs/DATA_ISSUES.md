# Data Integrity Issues

## Overview
This document outlines known data integrity issues in Chrome Tab Manager (TabPilot) and their recommended solutions.

## ID: DATA-001
**Title:** Timestamp Persistence Uses Weak Debouncing
**Severity:** P2
**Type:** data-integrity

### Evidence
- `ViewModel.swift:182-192` - `scheduleTimestampSave()` debounces 2 seconds
- `ViewModel.swift:173-179` - `saveTimestamps()` writes to UserDefaults

### Current Behavior
Timestamps are saved with a 2-second debounce. If the application crashes before the debounce timer fires, timestamp data is lost.

### Expected Behavior
Either immediate persistence for critical timestamp data or implementation of a crash recovery mechanism to minimize data loss window.

### Root Cause Hypothesis
Performance optimization that introduces an unacceptable data loss window for user-facing timestamps.

### Fix Direction
Option 1: Save synchronously on important timestamp updates (accept minor performance cost)
Option 2: Implement application state checkpointing to recover unsaved changes on relaunch
Option 3: Accept the data loss as a documented trade-off with clear user messaging

### Acceptance Criteria
Clearly document the data loss window and its impact on user experience.

### Test Plan
1. Simulate application crash before 2-second timer fires
2. Verify timestamp data loss occurs
3. Measure impact on user-visible features (e.g., tab opening times, duplicate detection accuracy)

### Confidence
High

## ID: DATA-002
**Title:** Tab ID Stability Issue - ID Changes When Tab Moves
**Severity:** P1
**Type:** bug

### Evidence
- `ChromeController.swift:64-69` - Stable ID includes windowId and tabIndex
- `ChromeController.swift:638` - ID changes when tab moves between windows

### Current Behavior
`stableTabId` uses `windowId:tabIndex:url|hash`. When a tab moves between windows, its ID changes, causing loss of associated history (opening time, user interactions, etc.).

### Expected Behavior
Tabs should maintain a stable ID across window moves to preserve history and user context.

### Root Cause Hypothesis
WindowId is included in the stable ID when it should only use content-based properties that remain constant when a tab moves.

### Fix Direction
Remove `windowId` from the stable ID calculation. Use only content-based ID (URL hash combined with tab-specific immutable properties).

### Acceptance Criteria
Tab moved between windows retains the same ID and associated `openedAt` timestamp.

### Test Plan
1. Create a tab in Window A
2. Record its ID and openedAt timestamp
3. Move tab to Window B
4. Verify ID and openedAt timestamp remain unchanged
5. Confirm history and user data associated with the tab is preserved

### Confidence
Medium

## Related Data Architecture Notes

### Data Ownership: UNCLEAR
- ViewModel appears to own timestamp data
- However, various managers (AutoCleanupManager, SnapshotManager, etc.) modify this data
- This creates potential race conditions and inconsistent state

### Persistence: PARTIAL
- Mixed use of UserDefaults and file-based storage
- No clear separation between:
  - Ephemeral UI state (suitable for UserDefaults)
  - Persistent user data (should use file storage or proper database)
  - Cache/performance data (could use either with clear invalidation strategy)

### Recommended Improvements

#### Short-Term (Before Launch)
1. **Document current data loss windows** in user-facing documentation
2. **Add crash logging** to detect when data loss occurs in the wild
3. **Consider reducing debounce interval** for critical timestamp data (e.g., from 2s to 0.5s)
4. **Add explicit comments** in code about data ownership and persistence strategies

#### Medium-Term (Post-Launch)
1. **Implement proper data layer separation**
   - Define clear data models for different data types
   - Establish ownership rules (who can read/write what)
2. **Consider adopting a proper persistence solution**
   - Core Data or SQLite for complex relational data
   - Well-defined UserDefaults usage for simple preferences
   - File storage for large blobs or export data
3. **Implement application state snapshot/recovery**
   - Periodic checkpoints of critical state
   - Recovery on launch from last known good state
4. **Add data validation and reconciliation**
   - On-launch checks for data consistency
   - Automatic repair of common corruption scenarios

#### Long-Term
1. **Implement user-controlled data export/import**
   - Allow users to backup and restore their TabPilot state
   - Provide transparency into what data is stored
2. **Add data usage analytics** (opt-in, privacy-first)
   - Understand how data is actually used to prioritize fixes
3. **Consider implementing data versioning**
   - Schema migrations for data format changes
   - Backward compatibility for older data versions

## Impact Assessment

### DATA-001 Impact
- **User Experience**: Minor inconvenience; users may notice tab opening times reset after crashes
- **Functionality**: Could affect duplicate detection accuracy if timestamps are used for "keep oldest/newest" logic
- **Frequency**: Depends on app crash rate; should be low with stable code
- **Severity**: Low-Medium for most users, potentially Higher for power users who rely on precise timing

### DATA-002 Impact
- **User Experience**: Loss of tab history when reorganizing Chrome windows
- **Functionality**: Breaks continuity of user experience; protected domain status, notes, or other tab-specific data may be lost
- **Frequency**: Common occurrence for users who organize tabs across windows
- **Severity**: Medium-High; directly contradicts the app's purpose of tab management

## Monitoring and Detection

### Suggested Telemetry (Opt-In, Privacy-First)
1. **Data Loss Events**: Timestamp when app launches and detects missing recent timestamp updates
2. **ID Change Events**: Count of tabs whose IDs change between sessions (indicating potential window moves)
3. **Recovery Success Rate**: Percentage of times crash recovery successfully restores state

### Logging Recommendations
1. Add debug logs when timestamp debounce is interrupted by termination
2. Log tab ID generation and changes for troubleshooting
3. Create data consistency checker that runs on launch

## Customer Communication

### For DATA-001 (Timestamp Debouncing)
If asked about timestamp accuracy:
> "TabPilot uses performance optimizations to keep the app responsive. Under rare circumstances (like app crashes), very recent timestamp data may not be saved. This typically affects only the most recent tab interactions and has minimal impact on duplicate detection accuracy."

### For DATA-002 (Tab ID Stability)
This is a confirmed bug that should be fixed before launch as it directly impacts core functionality. No customer communication workaround is sufficient - the fix should be implemented.

## Action Items

### Immediate (Before Launch)
1. [ ] Fix DATA-002: Remove windowId from stableTabId calculation in ChromeController.swift
2. [ ] Reduce timestamp debounce interval to 1 second for critical data
3. [ ] Add explicit documentation comments about data ownership in ViewModel.swift
4. [ ] Add launch-time data consistency check for timestamp data
5. [ ] Update QA test plans to verify tab ID stability across window moves

### Post-Launch
1. [ ] Implement proper data layer architecture with clear ownership
2. [ ] Add application state checkpointing mechanism
3. [ ] Create user-facing data export/import functionality
4. [ ] Add opt-in analytics to measure real-world impact of data issues
5. [ ] Consider migrating to Core Data or SQLite for complex tab history data