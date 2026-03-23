import Foundation

// MARK: - App Data Export Format

/// Universal app data export/import container.
/// Exported as a single JSON file containing all user data.
struct AppDataSnapshot: Codable {
    let exportedAt: Date
    let appVersion: String
    let schemaVersion: Int

    let cleanupRules: [CleanupRule]
    let urlPatterns: [URLPattern]
    let sessions: [Session]
    let closedTabHistory: [ClosedTabRecord]
    let statistics: TabStatistics?

    static let currentSchemaVersion = 1

    @MainActor
    static func capture() -> AppDataSnapshot {
        AppDataSnapshot(
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            schemaVersion: currentSchemaVersion,
            cleanupRules: CleanupRuleStore.shared.rules,
            urlPatterns: URLPatternStore.shared.loadPatterns(),
            sessions: SessionStore.shared.sessions,
            closedTabHistory: ClosedTabHistoryStore.shared.load(),
            statistics: StatisticsStore.shared.load()
        )
    }

    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func fromJSON(_ data: Data) throws -> AppDataSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppDataSnapshot.self, from: data)
    }
}

// MARK: - Import/Export Manager

@MainActor
final class AppDataManager {
    static let shared = AppDataManager()
    private init() {}

    /// Export all app data to a JSON file. Returns the file URL on success.
    func exportToFile() throws -> URL {
        let snapshot = AppDataSnapshot.capture()
        let data = try snapshot.toJSON()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "ChromeTabManager-backup-\(formatter.string(from: Date())).json"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    /// Import app data from a JSON file, merging or replacing based on `replace` flag.
    func importFromFile(at url: URL, replace: Bool = false) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let imported = try AppDataSnapshot.fromJSON(data)
        return apply(imported, replace: replace)
    }

    @discardableResult
    private func apply(_ snapshot: AppDataSnapshot, replace: Bool) -> ImportResult {
        var added = ImportResult()

        // Cleanup rules
        if replace {
            CleanupRuleStore.shared.replaceAll(snapshot.cleanupRules)
            added.cleanupRules = snapshot.cleanupRules.count
        } else {
            let existing = Set(CleanupRuleStore.shared.rules.map { $0.id })
            let newRules = snapshot.cleanupRules.filter { !existing.contains($0.id) }
            newRules.forEach { CleanupRuleStore.shared.add($0) }
            added.cleanupRules = newRules.count
        }

        // URL patterns
        if replace {
            URLPatternStore.shared.savePatterns(snapshot.urlPatterns)
            added.urlPatterns = snapshot.urlPatterns.count
        } else {
            let existing = Set(URLPatternStore.shared.loadPatterns().map { $0.id })
            let newPatterns = snapshot.urlPatterns.filter { !existing.contains($0.id) }
            let allPatterns = URLPatternStore.shared.loadPatterns() + newPatterns
            URLPatternStore.shared.savePatterns(allPatterns)
            added.urlPatterns = newPatterns.count
        }

        // Sessions
        if replace {
            SessionStore.shared.sessions = snapshot.sessions
            added.sessions = snapshot.sessions.count
        } else {
            let existingSessions = Set(SessionStore.shared.sessions.map { $0.id })
            let newSessions = snapshot.sessions.filter { !existingSessions.contains($0.id) }
            SessionStore.shared.sessions.append(contentsOf: newSessions)
            added.sessions = newSessions.count
        }

        // Closed tab history (always merge, never replace — history is additive)
        let existingHistory = Set(ClosedTabHistoryStore.shared.load().map { $0.id })
        let newHistory = snapshot.closedTabHistory.filter { !existingHistory.contains($0.id) }
        for record in newHistory {
            ClosedTabHistoryStore.shared.add(record)
        }
        added.closedTabHistory = newHistory.count

        return added
    }
}

struct ImportResult {
    var cleanupRules = 0
    var urlPatterns = 0
    var sessions = 0
    var closedTabHistory = 0
    var archiveEntries = 0

    var totalImported: Int {
        cleanupRules + urlPatterns + sessions + closedTabHistory + archiveEntries
    }

    var summary: String {
        var parts: [String] = []
        if cleanupRules > 0 { parts.append("\(cleanupRules) rules") }
        if urlPatterns > 0 { parts.append("\(urlPatterns) patterns") }
        if sessions > 0 { parts.append("\(sessions) sessions") }
        if closedTabHistory > 0 { parts.append("\(closedTabHistory) history entries") }
        return parts.isEmpty ? "Nothing new imported" : "Imported: \(parts.joined(separator: ", "))"
    }
}
