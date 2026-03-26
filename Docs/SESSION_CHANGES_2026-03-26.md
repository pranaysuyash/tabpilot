# Session Changes — 2026-03-26

## Overview

This session added four major features to TabPilot (Chrome Tab Manager):

1. **Domain Analytics Tracking** — Most tabs by domain, most duplicates by domain
2. **Duplicate Time Tracking** — Estimated and real-time time wasted on duplicate tabs
3. **Chrome Extension for Real Tab Time** — Native messaging bridge for actual dwell time per domain
4. **Cleanup Impact View** — Before/after memory/CPU metrics after closing tabs

---

## 1. Domain Analytics Tracking

### What was added
Persistent tracking of per-domain tab counts and duplicate counts, displayed in both the sidebar and the statistics modal.

### Files modified
- `Sources/ChromeTabManager/Stores/StatisticsStore.swift`
- `Sources/ChromeTabManager/Views/StatisticsView.swift`
- `Sources/ChromeTabManager/Views/SidebarView.swift`
- `Sources/ChromeTabManager/Features/Scan/ScanController.swift`

### Details

**StatisticsStore.swift** — Added three new fields to `TabStatistics`:
```swift
var tabsByDomain: [String: Int] = [:]
var duplicatesByDomain: [String: Int] = [:]
var totalDuplicateWastedSeconds: Double = 0
```

Added computed properties:
- `topDomainsByTabCount` — ranked top 10 domains by tab count
- `topDomainsByDuplicateCount` — ranked top 10 domains by duplicate count

Added `recordDomainAnalytics(tabsByDomain:duplicatesByDomain:duplicateWastedSeconds:)` method.

Added `recordDomainAnalytics(tabs:duplicates:)` on the `StatisticsStore` actor that computes domain breakdowns and wasted time from live scan data.

**StatisticsView.swift** — Complete rewrite with new sections:
- "Duplicate Time Wasted" in Session Overview
- "Top Domains by Tab Count" — bar chart with live data
- "Most Duplicates by Domain" — bar chart with live data
- "Historical Top Domains" — from persisted stats
- "Historical Duplicate Domains" — from persisted stats
- Added `DomainAnalyticsSection` reusable component with ranked bar visualization
- Changed from fixed-height VStack to ScrollView

**SidebarView.swift** — Added "Top Domains" section:
- Shows top 5 domains with tab count badges
- Badges turn orange when domain has duplicates
- Shows duplicate count subtitle per domain
- Added `TopDomainsSummaryView` component

**ScanController.swift** — Added `recordDomainAnalytics` call after both scan paths (rescan and _performScan).

### How it works
After each scan, the controller computes per-domain tab counts from the live tab list and per-domain duplicate counts from duplicate groups. "Duplicate time wasted" is calculated as the sum of ages of all tabs beyond the first in each duplicate group (cumulative open time of redundant copies).

---

## 2. Duplicate Time Tracking (Estimated)

### What was added
`totalDuplicateWastedSeconds` field tracks the estimated cumulative time that duplicate tabs have been sitting open unused.

### Calculation
```
wastedSeconds = Σ (for each duplicate group) Σ (for each tab except the first) age_of_tab
```

This represents "tab-hours wasted" — the total time that redundant tab copies have been consuming screen space and memory.

### Display
Shown in the StatisticsView Session Overview as "Duplicate Time Wasted" with orange styling.

---

## 3. Chrome Extension + Native Messaging Bridge

### Architecture
```
Chrome Extension (background.js)
    │
    │ chrome.runtime.sendNativeMessage / connectNative
    ▼
TabTimeHost (Swift executable)
    │
    │ Writes JSON to ~/Library/Application Support/TabPilot/tab_time_data.json
    ▼
TabTimeStore (actor in main app)
    │
    ▼
StatisticsView / SidebarView
```

### Files created

**`extension/manifest.json`** — Chrome Manifest V3 extension
- Permissions: `tabs`, `storage`, `idle`, `nativeMessaging`
- Service worker: `background.js`

**`extension/background.js`** — ~200 lines
- Tracks tab focus time using:
  - `chrome.tabs.onActivated` — tab switch within window
  - `chrome.windows.onFocusChanged` — window switch / Chrome loses focus
  - `chrome.tabs.onUpdated` — navigation / URL change
  - `chrome.tabs.onCreated` / `onRemoved` — tab lifecycle
  - `chrome.idle.onStateChanged` — pauses when user is idle/locked
- Accumulates per-domain time in memory
- Syncs to native host every 30 seconds via `chrome.runtime.connectNative`
- Persists to `chrome.storage.local` as backup
- Idle detection threshold: 60 seconds

**`extension/install_host.sh`** — Registers the native messaging host
- Creates manifest at `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.tabpilot.timetracker.json`
- Points to the TabTimeHost executable

**`extension/com.tabpilot.timetracker.json`** — Host manifest template

**`Sources/TabTimeHost/TabTimeHost.swift`** — Native messaging host executable (~130 lines)
- Implements Chrome native messaging protocol (4-byte LE length prefix + JSON)
- Reads messages from stdin, writes responses to stdout
- Writes accumulated timing data to `~/Library/Application Support/TabPilot/tab_time_data.json`
- Handles `tab_time_update` and `ping` message types
- Merges data across sessions (keeps today's data, resets on new day)

**`Sources/ChromeTabManager/Stores/TabTimeStore.swift`** — Actor for reading extension data
- Reads the JSON file written by TabTimeHost
- 5-second cache to avoid excessive file I/O
- Methods: `timeForDomain()`, `topDomains()`, `totalActiveTime()`, `isAvailable()`
- Only returns data matching today's date

**`Package.swift`** — Added `TabTimeHost` executable target

### Data format
```json
{
  "lastUpdated": 1711440000000,
  "date": "2026-03-26",
  "domainTime": {
    "github.com": 3600000,
    "stackoverflow.com": 1800000,
    "youtube.com": 900000
  },
  "tabs": {
    "123": { "url": "https://github.com/...", "domain": "github.com", "totalMs": 3600000 }
  }
}
```

### Setup steps
1. Build: `swift build`
2. Install host: `bash extension/install_host.sh`
3. Load extension: Chrome → `chrome://extensions` → Developer mode → Load unpacked → select `extension/`

### Graceful degradation
- Extension works without native host (data stored in `chrome.storage.local` only)
- App shows "via extension" badge when real-time data is available
- Falls back to age-based estimates when extension data isn't present

---

## 4. Cleanup Impact View

### What was added
After closing tabs (via any method), a sheet displays before/after system metrics showing the resource impact of the cleanup.

### Files created/modified

**`Sources/ChromeTabManager/Core/Models/SystemMetrics.swift`** — New file (~140 lines)

`SystemMetrics` struct captures:
- `chromeMemoryMB` — Total RSS of all Chrome processes
- `chromeProcessCount` — Number of Chrome/helper processes
- `chromeCPUPercent` — Total CPU % across Chrome processes
- `systemMemoryUsedMB` — System-wide used memory (active + wired + compressed)
- `systemMemoryTotalMB` — Total physical memory
- `systemMemoryFreeMB` — Free memory

Uses:
- `/bin/ps` for Chrome process RSS and CPU
- `/usr/bin/pgrep` for Chrome PIDs
- `host_statistics64` Mach API for accurate system memory
- `ProcessInfo.processInfo.physicalMemory` for total memory

`CleanupImpact` struct computes deltas:
- `chromeMemoryFreedMB` / `chromeMemoryFreedPercent`
- `systemMemoryFreedMB`
- `chromeCPUChange`

**`Sources/ChromeTabManager/Views/CleanupImpactView.swift`** — New file (~200 lines)
- Header with "Cleanup Impact" title
- Summary row: tabs closed, memory freed, CPU saved
- Comparison rows: Chrome Memory, System Memory, Chrome Processes, Chrome CPU
- Each row shows Before → After with delta badge (green for improvement)
- `ImpactStat` and `ComparisonRow` reusable components

**`Sources/ChromeTabManager/AppViewModel.swift`** — Modified
- Added `@Published var cleanupImpact: CleanupImpact?`
- Added `@Published var showCleanupImpact = false`
- Modified `closeSelectedTabs()`: captures before metrics, closes, waits 2s, captures after, shows impact sheet
- Modified `executeReviewPlan()`: same pattern
- Modified `closeAllDuplicates()`: same pattern

**`Sources/ChromeTabManager/ContentView.swift`** — Modified
- Added `.sheet(isPresented: $viewModel.showCleanupImpact)` presenting `CleanupImpactView`

### Flow
```
User clicks "Close Selected"
  → capture before metrics
  → close tabs via Chrome AppleScript
  → scan() to refresh
  → wait 2s for Chrome to release memory
  → capture after metrics
  → show CleanupImpactView sheet
```

---

## Complete File Inventory

### New files (9)
| File | Purpose |
|------|---------|
| `extension/manifest.json` | Chrome extension manifest |
| `extension/background.js` | Tab time tracking service worker |
| `extension/install_host.sh` | Native host registration script |
| `extension/com.tabpilot.timetracker.json` | Host manifest template |
| `Sources/TabTimeHost/TabTimeHost.swift` | Native messaging host executable |
| `Sources/.../Stores/TabTimeStore.swift` | Reads extension timing data |
| `Sources/.../Core/Models/SystemMetrics.swift` | System metrics capture |
| `Sources/.../Views/CleanupImpactView.swift` | Before/after metrics UI |
| `Docs/SESSION_CHANGES_2026-03-26.md` | This file |

### Modified files (6)
| File | Changes |
|------|---------|
| `Package.swift` | Added `TabTimeHost` executable target |
| `Sources/.../Stores/StatisticsStore.swift` | Added domain analytics fields + methods |
| `Sources/.../Views/StatisticsView.swift` | Full rewrite with domain analytics + extension data |
| `Sources/.../Views/SidebarView.swift` | Added Top Domains section with time data |
| `Sources/.../Features/Scan/ScanController.swift` | Added `recordDomainAnalytics` calls |
| `Sources/.../ContentView.swift` | Added CleanupImpactView sheet |
| `Sources/.../AppViewModel.swift` | Added impact metrics to all 3 cleanup methods |

---

## Testing Notes

- Build verified: `swift build` passes (only pre-existing warning in `BrowserAdapters.swift`)
- Tests verified: `swift test` — 37 tests pass, 0 failures
- SystemMetrics uses Mach APIs that require no special entitlements
- Native messaging host is a standalone executable (no app bundle needed for development)
- Extension requires manual load via `chrome://extensions` Developer mode
- Cleanup impact captures are async and non-blocking
- 2-second delay after cleanup allows Chrome to release memory before "after" snapshot

## Pending / TODO

- [ ] **Extension icons**: `icon16.png`, `icon48.png`, `icon128.png` need to be created and placed in `extension/`
- [ ] **TabTimeData duplication**: `TabTimeData` struct defined in both `TabTimeStore.swift` (app) and `TabTimeHost.swift` (host). Works because they're separate modules, but should ideally share a common definition to prevent schema drift
- [ ] **Native messaging host installation**: Currently manual via `extension/install_host.sh`. Should be automated in-app on first launch or during app install
- [ ] **Extension auto-install**: No mechanism yet to guide users to install the Chrome extension (could add a prompt in preferences when extension data isn't detected)
- [ ] **Historical time tracking**: Currently only tracks today's data. Could extend to keep a rolling history for trend analysis
- [ ] **Per-tab active time in sidebar**: The sidebar currently shows per-domain time. Could also show per-tab active time for the selected duplicate group
