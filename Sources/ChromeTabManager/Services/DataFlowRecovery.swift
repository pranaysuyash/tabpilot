import Foundation

enum DataOperation: String, Codable {
    case create
    case update
    case delete
}

struct DataChangeEvent: Codable {
    let timestamp: Date
    let entityType: String
    let entityId: String
    let operation: DataOperation
    let oldValue: Data?
    let newValue: Data?
    let userAction: String
}

/// Lightweight in-memory audit trail; can be swapped for persistence later.
actor DataAuditor {
    private var events: [DataChangeEvent] = []

    func logChange(_ event: DataChangeEvent) {
        events.append(event)
    }

    func getChanges(for entityId: String) -> [DataChangeEvent] {
        events.filter { $0.entityId == entityId }
    }

    func allChanges() -> [DataChangeEvent] {
        events
    }
}

struct ExportMetadata: Codable {
    let appVersion: String
    let buildNumber: String?
}

struct ClosedTabExport: Codable {
    let id: String
    let title: String
    let url: String
    let closedAt: Date
}

struct DailyStatsExport: Codable {
    let date: Date
    let tabsClosed: Int
    let sessionsCount: Int
}

struct PreferencesExport: Codable {
    let protectedDomains: [String]
    let includePinnedTabs: Bool
    let includeGroupedTabs: Bool
}

struct ArchiveReference: Codable {
    let id: String
    let name: String
    let createdAt: Date
}

struct LegacyAppDataExport: Codable {
    let version: String
    let exportDate: Date
    let metadata: ExportMetadata

    let tabHistory: [ClosedTabExport]
    let statistics: [DailyStatsExport]
    let preferences: PreferencesExport
    let archives: [ArchiveReference]
}

enum ImportError: Error {
    case incompatibleVersion
    case invalidData
}
