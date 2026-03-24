import Foundation

enum AppDataImportError: LocalizedError {
    case unsupportedSchemaVersion(imported: Int, supported: Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(imported, supported):
            return "Unsupported backup schema version \(imported). This app supports up to version \(supported)."
        }
    }
}

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
        return try apply(imported, replace: replace)
    }

    @discardableResult
    private func apply(_ snapshot: AppDataSnapshot, replace: Bool) throws -> ImportResult {
        guard snapshot.schemaVersion <= AppDataSnapshot.currentSchemaVersion else {
            throw AppDataImportError.unsupportedSchemaVersion(
                imported: snapshot.schemaVersion,
                supported: AppDataSnapshot.currentSchemaVersion
            )
        }

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
            SessionStore.shared.appendSessions(newSessions)
            added.sessions = newSessions.count
        }

        // Closed tab history
        if replace {
            ClosedTabHistoryStore.shared.save(snapshot.closedTabHistory)
            added.closedTabHistory = snapshot.closedTabHistory.count
        } else {
            let existingHistory = Set(ClosedTabHistoryStore.shared.load().map { $0.id })
            let newHistory = snapshot.closedTabHistory.filter { !existingHistory.contains($0.id) }
            for record in newHistory {
                ClosedTabHistoryStore.shared.add(record)
            }
            added.closedTabHistory = newHistory.count
        }

        // Statistics
        if replace {
            StatisticsStore.shared.save(snapshot.statistics ?? TabStatistics())
            added.statisticsImported = snapshot.statistics != nil
        } else if let importedStats = snapshot.statistics {
            let mergedStats = mergeStatistics(current: StatisticsStore.shared.load(), imported: importedStats)
            StatisticsStore.shared.save(mergedStats)
            added.statisticsImported = true
        }

        return added
    }

    private func mergeStatistics(current: TabStatistics, imported: TabStatistics) -> TabStatistics {
        var merged = current
        merged.totalTabsClosed += imported.totalTabsClosed
        merged.duplicateTabsClosed += imported.duplicateTabsClosed
        merged.sessionsCount += imported.sessionsCount
        merged.totalSavingsSeconds += imported.totalSavingsSeconds
        merged.lastSessionDate = [current.lastSessionDate, imported.lastSessionDate].compactMap { $0 }.max()

        for (domain, count) in imported.mostClosedDomains {
            merged.mostClosedDomains[domain, default: 0] += count
        }

        merged.tabDebtHistory.append(contentsOf: imported.tabDebtHistory)
        if merged.tabDebtHistory.count > 30 {
            merged.tabDebtHistory = Array(merged.tabDebtHistory.suffix(30))
        }

        if let importedLastDate = imported.lastRecordedDate,
           importedLastDate > (merged.lastRecordedDate ?? .distantPast) {
            merged.lastRecordedDate = imported.lastRecordedDate
            merged.lastRecordedTabCount = imported.lastRecordedTabCount
            merged.tabDebtScore = imported.tabDebtScore
        }

        return merged
    }
}

struct ImportResult {
    var cleanupRules = 0
    var urlPatterns = 0
    var sessions = 0
    var closedTabHistory = 0
    var statisticsImported = false

    var totalImported: Int {
        cleanupRules + urlPatterns + sessions + closedTabHistory + (statisticsImported ? 1 : 0)
    }

    var summary: String {
        var parts: [String] = []
        if cleanupRules > 0 { parts.append("\(cleanupRules) rules") }
        if urlPatterns > 0 { parts.append("\(urlPatterns) patterns") }
        if sessions > 0 { parts.append("\(sessions) sessions") }
        if closedTabHistory > 0 { parts.append("\(closedTabHistory) history entries") }
        if statisticsImported { parts.append("statistics") }
        return parts.isEmpty ? "Nothing new imported" : "Imported: \(parts.joined(separator: ", "))"
    }
}
