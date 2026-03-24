import Foundation

/// Domain entity representing scan statistics
struct ScanStatsEntity: Codable {
    let totalTabs: Int
    let windowCount: Int
    let duplicateGroups: Int
    let wastedTabs: Int
    let uniqueUrls: Int
}

/// Domain entity representing scan telemetry for debugging
struct ScanTelemetryEntity: Codable {
    let windowsAttempted: Int
    let windowsFailed: Int
    let tabsFound: Int
    let errors: [String]
    let durationSeconds: Double
}

/// Domain entity representing a browser window with its tabs
struct WindowEntity: Identifiable {
    let windowId: Int
    let tabCount: Int
    let tabs: [TabEntity]
    let activeTabIndex: Int

    var id: Int { windowId }
}

/// Result of a tab scan operation
struct ScanResult {
    let windows: [WindowEntity]
    let stats: ScanStatsEntity
    let telemetry: ScanTelemetryEntity
}

/// Result of a tab close operation
struct CloseResult {
    let closedCount: Int
    let failedIds: [String]
    let errors: [String]
}

/// Target for tab operations
struct TabTarget {
    let windowId: Int
    let tabIndex: Int
    let tabId: String
}
