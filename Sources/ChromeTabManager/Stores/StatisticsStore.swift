import Foundation

struct TabStatistics: Codable {
    var totalTabsClosed: Int = 0
    var duplicateTabsClosed: Int = 0
    var sessionsCount: Int = 0
    var lastSessionDate: Date?
    var mostClosedDomains: [String: Int] = [:]
    var totalSavingsSeconds: Double = 0

    mutating func recordClose(domain: String, estimatedSavingsSeconds: Double) {
        totalTabsClosed += 1
        totalSavingsSeconds += estimatedSavingsSeconds
        mostClosedDomains[domain, default: 0] += 1
    }

    mutating func recordSession() {
        sessionsCount += 1
        lastSessionDate = Date()
    }
}

final class StatisticsStore: @unchecked Sendable {
    static let shared = StatisticsStore()

    private let statsKey = "tabStatistics"
    private let userDefaults = UserDefaults.standard
    private let lock = NSLock()

    private init() {}

    func load() -> TabStatistics {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: statsKey) else {
            return TabStatistics()
        }

        do {
            return try JSONDecoder().decode(TabStatistics.self, from: data)
        } catch {
            SecureLogger.error("StatisticsStore: Failed to decode statistics: \(error.localizedDescription)")
            return TabStatistics()
        }
    }

    func save(_ stats: TabStatistics) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let data = try JSONEncoder().encode(stats)
            userDefaults.set(data, forKey: statsKey)
        } catch {
            SecureLogger.error("StatisticsStore: Failed to encode statistics: \(error.localizedDescription)")
        }
    }

    func recordClose(domain: String, estimatedSavingsSeconds: Double = 300) {
        var stats = load()
        stats.recordClose(domain: domain, estimatedSavingsSeconds: estimatedSavingsSeconds)
        save(stats)
    }

    func recordSession() {
        var stats = load()
        stats.recordSession()
        save(stats)
    }

    func getStats() -> TabStatistics {
        return load()
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: statsKey)
    }
}
