import Foundation

struct ClosedTabRecord: Codable, Identifiable {
    let id: UUID
    let windowId: Int
    let url: String
    let title: String
    let closedAt: Date

    init(windowId: Int, url: String, title: String, closedAt: Date = Date()) {
        self.id = UUID()
        self.windowId = windowId
        self.url = url
        self.title = title
        self.closedAt = closedAt
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
            print("ClosedTabHistoryStore: Failed to decode history: \(error.localizedDescription)")
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
            print("ClosedTabHistoryStore: Failed to encode history: \(error.localizedDescription)")
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
}
