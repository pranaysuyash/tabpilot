import Foundation

/// Manages saving and loading tab session snapshots as JSON files for safety and history.
/// File operations run on background threads to avoid blocking UI (CONCURRENCY-007 Fix)
final class SnapshotManager: @unchecked Sendable {
    static let shared = SnapshotManager()
    
    private let fileManager = FileManager.default
    private let dateFormatter = ISO8601DateFormatter()
    
    private var snapshotsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ChromeTabManager/Snapshots")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    init() {
        dateFormatter.formatOptions = [.withFullDate, .withFullTime]
    }
    
    /// Save current tabs to a timestamped JSON file.
    /// Runs on background thread to avoid blocking UI (CONCURRENCY-007 Fix)
    func saveSnapshot(tabs: [TabInfo], label: String = "auto") {
        let exportData = tabs.map { ExportTab(title: $0.title, url: $0.url, windowId: $0.windowId, tabIndex: $0.tabIndex, openedAt: $0.openedAt) }
        let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "snapshot_\(timestamp)_\(label).json"
        let targetURL = snapshotsDirectory.appendingPathComponent(filename)
        
        Task(priority: .background) {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(exportData)
                let protectionAttributes: [FileAttributeKey: Any] = [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                ]
                try data.write(to: targetURL)
                try FileManager.default.setAttributes(protectionAttributes, ofItemAtPath: targetURL.path)
                await MainActor.run {
                    SecureLogger.info("Snapshot saved successfully")
                }
            } catch {
                await MainActor.run {
                    SecureLogger.error("Failed to save snapshot: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// List available snapshots asynchronously.
    /// Runs on background thread to avoid blocking UI (CONCURRENCY-007 Fix)
    func listSnapshots() async -> [URL] {
        let directory = snapshotsDirectory
        
        return await Task(priority: .background) {
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
                return []
            }
            return files.filter { $0.pathExtension == "json" }.sorted {
                let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return date1 > date2
            }
        }.value
    }
}

private struct ExportTab: Codable {
    let title: String
    let url: String
    let windowId: Int
    let tabIndex: Int
    let openedAt: Date
}
