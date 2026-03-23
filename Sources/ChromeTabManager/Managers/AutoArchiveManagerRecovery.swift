import Foundation

// RECOVERY ADDON: additive manager to select stale tabs for archival workflows.
@MainActor
final class AutoArchiveManagerRecovery {
    func staleTabs(from tabs: [TabInfo], olderThan seconds: TimeInterval) -> [TabInfo] {
        let now = Date()
        return tabs.filter { now.timeIntervalSince($0.openedAt) >= seconds }
    }
}
