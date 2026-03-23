# Persistence Strategy

**Project:** Chrome Tab Manager  
**Last Updated:** 2026-03-23

---

## Decision Matrix

| Data Type | Storage | Rationale |
|-----------|---------|-----------|
| User Preferences | `UserDefaults` | Small, keyed, system-backed |
| Cleanup Rules | `UserDefaults` (JSON-encoded `[CleanupRule]`) | < 1 KB typically, instant access |
| URL Patterns | `UserDefaults` (JSON-encoded `[URLPattern]`) | Small list, rarely changes |
| Closed Tab History | `UserDefaults` (JSON-encoded, capped at 100) | Small, temporary, acceptable loss on reset |
| Sessions (saved sets) | `UserDefaults` (JSON-encoded `[Session]`) | < 100 sessions typical |
| Statistics | `UserDefaults` (JSON-encoded `TabStatistics`) | Aggregate counts, not raw events |
| Archive Entries | `UserDefaults` (JSON-encoded `[ArchiveEntry]`) | Moderate size; migrate to file if > 500 entries |
| Tab Timestamps | `UserDefaults` (Dictionary keyed by tab hash) | Updated per-scan; debounced to avoid write thrash |
| App Data Export | File (`.json` in Downloads or via NSSavePanel) | User-initiated; full fidelity |

---

## Rules

### Use UserDefaults when:
- Data is < 1 MB total
- Data is accessed on every launch
- Loss on UserDefaults reset is acceptable (non-critical)
- Codable types with stable schemas

### Use File storage when:
- Data exceeds 1 MB (e.g., thousands of archive entries)
- Data must survive UserDefaults resets
- User should be able to back up / move the file
- Location: `~/Library/Application Support/ChromeTabManager/`

### Use In-Memory only when:
- Data is derived/computed (e.g., `duplicateGroups`, `filteredTabs`)
- Data is rebuilt on every scan
- Data would be stale on restart anyway (scan telemetry, progress)

---

## Key Stores

### `UserDefaults` Keys (defined in `Utilities/DefaultsKeys.swift`)

| Key | Type | Default |
|-----|------|---------|
| `cleanupRules` | `[CleanupRule]` | `[]` |
| `urlPatterns` | `[URLPattern]` | `[]` |
| `closedTabHistory` | `[ClosedTabRecord]` | `[]` |
| `sessions` | `[Session]` | `[]` |
| `tabStatistics` | `TabStatistics` | zeroed |
| `tabFirstSeenTimestamps` | `[String: Date]` | `[:]` |
| `archiveEntries` | `[ArchiveEntry]` | `[]` |

---

## Write Patterns

### Debounced writes (tab timestamps)
Timestamps update on every scan. Batch-write with 2-second debounce to avoid hammering UserDefaults:

```swift
$tabs
    .debounce(for: .seconds(2), scheduler: RunLoop.main)
    .sink { [weak self] _ in self?.persistTimestamps() }
```

### Immediate writes (rules, sessions, patterns)
Write on every mutation since these are rare and small.

### Capped collections
- `ClosedTabHistoryStore`: max 100 records (drop oldest on overflow)
- `ArchiveAutoArchiveManager`: prune entries older than `retentionDays` preference

---

## Migration Strategy

When adding new fields to a `Codable` type:
1. Make new fields `Optional` or provide a `default` in `CodingKeys`
2. Increment a `schemaVersion: Int` static property on the type
3. In the store's `load()`, check `schemaVersion` and migrate if needed
4. Write migration in `Utilities/DataMigration.swift` (create if needed)

---

## Error Handling

All persistence operations use `SecureLogger.error()` on failure and return graceful defaults (empty array / zeroed struct). Silent failures are logged but never crash the app.
