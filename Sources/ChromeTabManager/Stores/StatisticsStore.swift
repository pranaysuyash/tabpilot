import Foundation

struct TabStatistics: Codable {
    var totalTabsClosed: Int = 0
    var duplicateTabsClosed: Int = 0
    var sessionsCount: Int = 0
    var lastSessionDate: Date?
    var mostClosedDomains: [String: Int] = [:]
    var totalSavingsSeconds: Double = 0
    
    // Tab Debt Tracking (P3)
    var tabDebtScore: Int = 100
    var tabDebtHistory: [TabDebtEntry] = []
    var lastRecordedTabCount: Int = 0
    var lastRecordedDate: Date?
    
    mutating func recordClose(domain: String, estimatedSavingsSeconds: Double) {
        totalTabsClosed += 1
        totalSavingsSeconds += estimatedSavingsSeconds
        mostClosedDomains[domain, default: 0] += 1
    }
    
    mutating func recordSession() {
        sessionsCount += 1
        lastSessionDate = Date()
    }
    
    mutating func recordTabDebt(tabCount: Int, duplicateCount: Int, date: Date = Date()) {
        let entry = TabDebtEntry(date: date, tabCount: tabCount, duplicateCount: duplicateCount)
        tabDebtHistory.append(entry)
        
        // Keep only last 30 entries
        if tabDebtHistory.count > 30 {
            tabDebtHistory.removeFirst(tabDebtHistory.count - 30)
        }
        
        lastRecordedTabCount = tabCount
        lastRecordedDate = date
        
        // Calculate debt score (100 = no debt, 0 = high debt)
        // Debt increases with: high tab count, high duplicate ratio, stale tabs
        let normalizedTabs = min(1.0, Double(tabCount) / 500.0)
        let normalizedDuplicates = Double(duplicateCount) / max(1.0, Double(tabCount))
        let debtRatio = (normalizedTabs * 0.5) + (normalizedDuplicates * 50.0)
        tabDebtScore = max(0, min(100, 100 - Int(debtRatio * 100)))
    }
    
    var debtTrend: DebtTrend {
        guard tabDebtHistory.count >= 2 else { return .stable }
        let recent = tabDebtHistory.suffix(5).map { $0.duplicateCount }
        let older = tabDebtHistory.prefix(5).map { $0.duplicateCount }
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let olderAvg = Double(older.reduce(0, +)) / Double(older.count)
        
        if recentAvg < olderAvg * 0.8 { return .improving }
        if recentAvg > olderAvg * 1.2 { return .worsening }
        return .stable
    }
}

struct TabDebtEntry: Codable {
    let date: Date
    let tabCount: Int
    let duplicateCount: Int
}

enum DebtTrend: String {
    case improving = "Improving"
    case worsening = "Worsening"
    case stable = "Stable"
    
    var icon: String {
        switch self {
        case .improving: return "arrow.down.right"
        case .worsening: return "arrow.up.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: String {
        switch self {
        case .improving: return "green"
        case .worsening: return "red"
        case .stable: return "orange"
        }
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
    
    func recordTabDebt(tabCount: Int, duplicateCount: Int) {
        var stats = load()
        stats.recordTabDebt(tabCount: tabCount, duplicateCount: duplicateCount)
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

    // MARK: - CSV Export

    private func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuoting ? "\"\(escaped)\"" : escaped
    }

    func exportToCSV() -> String {
        let stats = load()
        var csv = "TabPilot Statistics Export\n"
        csv += "Generated: \(csvEscape(Date().formatted(date: .complete, time: .shortened)))\n\n"

        // Summary
        csv += "SUMMARY\n"
        csv += "Total Tabs Closed,\(stats.totalTabsClosed)\n"
        csv += "Duplicate Tabs Closed,\(stats.duplicateTabsClosed)\n"
        csv += "Sessions Count,\(stats.sessionsCount)\n"
        csv += "Total Savings (seconds),\(Int(stats.totalSavingsSeconds))\n"
        csv += "Tab Debt Score,\(stats.tabDebtScore)\n\n"

        // Top Domains by tab count
        if !stats.mostClosedDomains.isEmpty {
            csv += "TOP DOMAINS BY TAB COUNT\n"
            let sorted = stats.mostClosedDomains.sorted { $0.value > $1.value }
            for (domain, count) in sorted.prefix(20) {
                csv += "\(csvEscape(domain)),\(count)\n"
            }
            csv += "\n"
        }

        // Tab Debt History
        if !stats.tabDebtHistory.isEmpty {
            csv += "TAB DEBT HISTORY\n"
            csv += "Date,Tab Count,Duplicate Count\n"
            let sorted = stats.tabDebtHistory.sorted { $0.date < $1.date }
            for entry in sorted {
                csv += "\(csvEscape(entry.date.formatted(date: .numeric, time: .shortened))),\(entry.tabCount),\(entry.duplicateCount)\n"
            }
        }

        return csv
    }

    func exportToCSVFile() -> URL? {
        let csv = exportToCSV()
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "TabPilot_Stats_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            SecureLogger.error("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }
}
