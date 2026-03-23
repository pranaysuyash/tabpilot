import Foundation

struct ClosedTabRecord: Codable, Identifiable {
    let id: UUID
    let windowId: Int
    let url: String
    let title: String
    let closedAt: Date
    var restoredAt: Date?

    var isRestored: Bool { restoredAt != nil }

    init(windowId: Int, url: String, title: String, closedAt: Date = Date()) {
        self.id = UUID()
        self.windowId = windowId
        self.url = url
        self.title = title
        self.closedAt = closedAt
        self.restoredAt = nil
    }

    fileprivate init(copying other: ClosedTabRecord, restoredAt: Date) {
        self.id = other.id
        self.windowId = other.windowId
        self.url = other.url
        self.title = other.title
        self.closedAt = other.closedAt
        self.restoredAt = restoredAt
    }
}

final class ClosedTabHistoryStore: @unchecked Sendable {
    static let shared = ClosedTabHistoryStore()

    private let historyKey = "closedTabHistory"
    private let maxHistorySize = 100
    private let userDefaults = UserDefaults.standard
    private let lock = NSLock()

    private init() {}

    func load() -> [ClosedTabRecord] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: historyKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ClosedTabRecord].self, from: data)
        } catch {
            SecureLogger.error("ClosedTabHistoryStore: Failed to decode history: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ records: [ClosedTabRecord]) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let data = try JSONEncoder().encode(records)
            userDefaults.set(data, forKey: historyKey)
        } catch {
            SecureLogger.error("ClosedTabHistoryStore: Failed to encode history: \(error.localizedDescription)")
        }
    }

    func add(_ record: ClosedTabRecord) {
        var history = load()
        history.insert(record, at: 0)

        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }

        save(history)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: historyKey)
    }

    func getRecent(count: Int = 10) -> [ClosedTabRecord] {
        return Array(load().prefix(count))
    }

    /// Returns the most recent `limit` entries (alias for API consistency).
    func recentEntries(limit: Int = 10) -> [ClosedTabRecord] {
        return getRecent(count: limit)
    }

    /// Marks a record as restored (tab was reopened) and persists the change.
    func markRestored(_ record: ClosedTabRecord) {
        var history = load()
        if let idx = history.firstIndex(where: { $0.id == record.id }) {
            history[idx] = ClosedTabRecord(copying: history[idx], restoredAt: Date())
            save(history)
        }
    }
}
