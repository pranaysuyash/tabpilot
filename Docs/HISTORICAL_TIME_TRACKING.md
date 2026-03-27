# Rolling Historical Time Tracking Implementation

## Summary

Implemented rolling historical time tracking for the Chrome extension data, replacing the single-day storage with a 30-day rolling history.

## Changes Made

### 1. Data Structures (`Sources/TabPilotModels/TabTimeData.swift`)

Added two new structures:

- **`DailyTimeRecord`** - Represents a single day's time tracking data
  - `date`: String (YYYY-MM-DD format)
  - `totalActiveTimeMs`: Total time across all domains
  - `domainTime`: Dictionary of domain -> milliseconds
  - `tabCount`: Number of tabs tracked
  - `savedAt`: Timestamp when record was saved
  - Convenience methods: `topDomains()`, `totalActiveTimeSeconds`

- **`HistoricalStatistics`** - Aggregate statistics across multiple days
  - `totalTimeSeconds`: Sum of all days
  - `averageDailyTimeSeconds`: Average per day
  - `aggregatedDomainTime`: Combined domain times across all days
  - `trend`: Trend analysis (increasing/decreasing/stable/noData)
  - `Trend` enum with descriptions and color hints

### 2. Storage Layer (`Sources/ChromeTabManager/Stores/TabTimeStore.swift`)

Enhanced with historical tracking capabilities:

- **New storage location**: `~/Library/Application Support/TabPilot/time_history/`
- **Daily files**: Each day's data stored as `YYYY-MM-DD.json`
- **Backward compatibility**: Still reads from legacy `tab_time_data.json`

**New Methods:**
- `loadHistory(days:)` - Load last N days of records
- `getHistory(from:to:)` - Get records for date range
- `getLastDays(_:)` - Convenience for last N days
- `saveDailyRecord()` - Persist today's data as historical record
- `getHistoricalStatistics(days:)` - Get aggregate stats
- `totalTimeForPeriod(days:)` - Total time across period
- `topDomainsForPeriod(days:limit:)` - Top domains across period
- `getTrend(days:)` - Trend analysis
- `hasRecord(for:)` - Check if date has data
- `availableHistoryDays` - Count of stored days
- `cleanupOldRecords()` - Automatic cleanup of records >30 days

**Features:**
- Lazy loading with caching (60s cache interval)
- Automatic directory creation
- Automatic cleanup of old records

### 3. UI Updates (`Sources/ChromeTabManager/Views/StatisticsView.swift`)

Added historical time tracking UI:

- **Time Range Selector**: Today / Last 7 Days / Last 30 Days
- **Trend Indicator**: Shows ↑/↓/→ with percentage change
- **Historical Stats**:
  - Total active time for selected period
  - Daily average
  - Days tracked count
  - Top domains aggregated across period
- **Smart Availability**: Only shows time ranges with available data

### 4. Tests (`Tests/ChromeTabManagerTests/HistoricalTimeTrackingTests.swift`)

Added comprehensive unit tests:
- `testDailyTimeRecordCreation` - Basic record creation
- `testDailyTimeRecordTopDomains` - Domain sorting
- `testHistoricalStatisticsAggregation` - Multi-day aggregation
- `testHistoricalStatisticsTrendIncreasing` - Trend detection (up)
- `testHistoricalStatisticsTrendDecreasing` - Trend detection (down)
- `testHistoricalStatisticsTrendStable` - Trend detection (stable)
- `testHistoricalStatisticsTrendNoData` - Edge cases
- `testTrendDescription` - UI formatting

## How to Test

### Manual Testing

1. **Build and Run**:
   ```bash
   swift build
   ```

2. **Run Tests**:
   ```bash
   swift test --filter HistoricalTimeTrackingTests
   ```

3. **Manual Verification**:
   - Install Chrome extension and use it for a day
   - Check `~/Library/Application Support/TabPilot/time_history/` for daily files
   - Open Statistics view in app
   - Verify "Today" shows current day's data
   - After 2+ days, verify "Last 7 Days" and "Last 30 Days" options appear

4. **Test Data Generation** (for development):
   ```swift
   // Create test data for multiple days
   let testDays = [
       DailyTimeRecord(date: "2024-03-24", totalActiveTimeMs: 3600000, domainTime: ["google.com": 3600000], tabCount: 3),
       DailyTimeRecord(date: "2024-03-25", totalActiveTimeMs: 7200000, domainTime: ["google.com": 3600000, "github.com": 3600000], tabCount: 5),
       DailyTimeRecord(date: "2024-03-26", totalActiveTimeMs: 5400000, domainTime: ["github.com": 5400000], tabCount: 4)
   ]
   ```

### Verify Features

- [ ] Historical data files created in `time_history/` directory
- [ ] Each day has separate JSON file named `YYYY-MM-DD.json`
- [ ] StatisticsView shows time range selector
- [ ] Trend indicator appears when viewing 7+ days
- [ ] Top domains aggregated correctly across days
- [ ] Old records (>30 days) automatically cleaned up
- [ ] Backward compatibility with legacy `tab_time_data.json`

## Storage Format

### Daily Record File (`2024-03-26.json`)
```json
{
  "id": "2024-03-26",
  "date": "2024-03-26",
  "totalActiveTimeMs": 7200000,
  "domainTime": {
    "google.com": 3600000,
    "github.com": 3600000
  },
  "tabCount": 8,
  "savedAt": "2024-03-26T23:59:59Z"
}
```

## Privacy & Performance

- **Privacy**: All data stays local (no cloud storage)
- **Storage**: ~10-50KB per day, ~1.5MB for 30 days
- **Performance**: Lazy loading with 60s cache
- **Cleanup**: Automatic deletion of records >30 days
- **Backward Compatible**: Existing single-day data still works

## Future Enhancements

Potential additions for future PRs:
- Export historical data to CSV/JSON
- Weekly/monthly summary reports
- Goal setting (e.g., "limit to 4 hours/day")
- Visualization charts (bar chart, line graph)
- Domain grouping (work vs personal)