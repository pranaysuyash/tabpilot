import Foundation

actor TabTimeStore {
    static let shared = TabTimeStore()
    
    // MARK: - Cache
    private var cached: TabTimeData?
    private var lastReadTime: Date?
    private let cacheInterval: TimeInterval = 5
    
    // MARK: - Historical Cache
    private var historicalCache: [String: DailyTimeRecord] = [:]
    private var lastHistoryLoad: Date?
    private let historyCacheInterval: TimeInterval = 60
    
    // MARK: - Paths
    private var legacyDataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("TabPilot/tab_time_data.json")
    }
    
    private var historyDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("TabPilot/time_history")
    }
    
    private var todayFileURL: URL {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return historyDirectoryURL.appendingPathComponent("\(today).json")
    }
    
    private init() {}
    
    // MARK: - Directory Management
    
    private func ensureHistoryDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: historyDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    /// Ensures the history directory exists - call this before file operations
    private func ensureDirectoryExists() {
        ensureHistoryDirectoryExists()
    }
    
    // MARK: - Legacy Support (Today's Data)
    
    func load() -> TabTimeData? {
        if let cached = cached,
           let lastRead = lastReadTime,
           Date().timeIntervalSince(lastRead) < cacheInterval {
            return cached
        }
        
        // Try new location first
        if let data = try? Data(contentsOf: todayFileURL),
           let decoded = try? JSONDecoder().decode(TabTimeData.self, from: data) {
            cached = decoded
            lastReadTime = Date()
            return decoded
        }
        
        // Fallback to legacy location
        guard let data = try? Data(contentsOf: legacyDataFileURL),
              let decoded = try? JSONDecoder().decode(TabTimeData.self, from: data) else {
            return nil
        }
        
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        guard decoded.date == String(today) else {
            cached = nil
            lastReadTime = Date()
            return nil
        }
        
        cached = decoded
        lastReadTime = Date()
        return decoded
    }
    
    func timeForDomain(_ domain: String) -> Double {
        guard let data = load() else { return 0 }
        return (data.domainTime[domain] ?? 0) / 1000.0
    }
    
    func topDomains(limit: Int = 10) -> [(domain: String, seconds: Double)] {
        guard let data = load() else { return [] }
        return data.domainTime
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (domain: $0.key, seconds: $0.value / 1000.0) }
    }
    
    func totalActiveTime() -> Double {
        guard let data = load() else { return 0 }
        return data.domainTime.values.reduce(0, +) / 1000.0
    }
    
    func isAvailable() -> Bool {
        return load() != nil
    }
    
    /// Get active time for a specific URL from tabDetails
    /// Returns time in seconds, or nil if not tracked
    func timeForURL(_ url: String) -> Double? {
        guard let data = load() else { return nil }
        // Normalize URL for matching (remove trailing slashes, etc.)
        let normalizedURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Try exact match first
        if let detail = data.tabDetails[normalizedURL] {
            return detail.totalMs / 1000.0
        }
        
        // Try matching without query parameters
        if let urlWithoutQuery = normalizedURL.components(separatedBy: "?").first,
           let detail = data.tabDetails[urlWithoutQuery] {
            return detail.totalMs / 1000.0
        }
        
        // Try matching by iterating (in case of minor differences)
        for (trackedURL, detail) in data.tabDetails {
            if trackedURL == normalizedURL || 
               trackedURL.hasPrefix(normalizedURL) ||
               normalizedURL.hasPrefix(trackedURL) {
                return detail.totalMs / 1000.0
            }
        }
        
        return nil
    }
    
    /// Get all tracked URLs with their times, sorted by time (most active first)
    func allTrackedURLs() -> [(url: String, seconds: Double)] {
        guard let data = load() else { return [] }
        return data.tabDetails
            .sorted { $0.value.totalMs > $1.value.totalMs }
            .map { (url: $0.key, seconds: $0.value.totalMs / 1000.0) }
    }
    
    func invalidateCache() {
        cached = nil
        lastReadTime = nil
    }
    
    // MARK: - Historical Data Methods
    
    /// Load all historical records (last 30 days by default)
    func loadHistory(days: Int = 30) -> [DailyTimeRecord] {
        // Ensure directory exists before accessing
        ensureDirectoryExists()
        
        // Check cache
        if let lastLoad = lastHistoryLoad,
           Date().timeIntervalSince(lastLoad) < historyCacheInterval,
           !historicalCache.isEmpty {
            return getSortedHistory(limit: days)
        }
        
        var records: [DailyTimeRecord] = []
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(at: historyDirectoryURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(DailyTimeRecord.self, from: data) else {
                continue
            }
            historicalCache[record.date] = record
            records.append(record)
        }
        
        lastHistoryLoad = Date()
        return getSortedHistory(limit: days)
    }
    
    /// Get historical records for a specific date range
    func getHistory(from startDate: Date, to endDate: Date) -> [DailyTimeRecord] {
        let allHistory = loadHistory(days: 365) // Load up to a year
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return allHistory.filter { record in
            guard let recordDate = formatter.date(from: record.date) else { return false }
            return recordDate >= startDate && recordDate <= endDate
        }
    }
    
    /// Get last N days of history
    func getLastDays(_ days: Int) -> [DailyTimeRecord] {
        return loadHistory(days: days)
    }
    
    /// Save today's data as a historical record
    func saveDailyRecord() async {
        guard let data = load() else { return }
        
        // Ensure directory exists before writing
        ensureDirectoryExists()
        
        let totalTime = data.domainTime.values.reduce(0, +)
        let record = DailyTimeRecord(
            date: data.date,
            totalActiveTimeMs: totalTime,
            domainTime: data.domainTime,
            tabCount: data.tabDetails.count
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encoded = try encoder.encode(record)
            try encoded.write(to: todayFileURL)
            
            // Update cache
            historicalCache[record.date] = record
            
            // Clean up old records
            cleanupOldRecords()
        } catch {
            print("Failed to save daily record: \(error)")
        }
    }
    
    /// Get historical statistics for analysis
    func getHistoricalStatistics(days: Int = 7) -> HistoricalStatistics {
        let history = getLastDays(days)
        return HistoricalStatistics(days: history)
    }
    
    /// Get total time across multiple days
    func totalTimeForPeriod(days: Int) -> Double {
        let history = getLastDays(days)
        return history.reduce(0) { $0 + $1.totalActiveTimeSeconds }
    }
    
    /// Get aggregated top domains across multiple days
    func topDomainsForPeriod(days: Int, limit: Int = 10) -> [(domain: String, seconds: Double)] {
        let history = getLastDays(days)
        var aggregated: [String: Double] = [:]
        
        for day in history {
            for (domain, ms) in day.domainTime {
                aggregated[domain, default: 0] += ms / 1000.0
            }
        }
        
        return aggregated
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (domain: $0.key, seconds: $0.value) }
    }
    
    /// Get trend for the last N days
    func getTrend(days: Int = 7) -> HistoricalStatistics.Trend {
        guard days >= 2 else { return .noData }
        let stats = getHistoricalStatistics(days: days)
        return stats.trend
    }
    
    /// Check if we have historical data for a specific date
    func hasRecord(for date: String) -> Bool {
        let fileURL = historyDirectoryURL.appendingPathComponent("\(date).json")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get the number of days with historical data
    var availableHistoryDays: Int {
        let history = loadHistory(days: 365)
        return history.count
    }
    
    // MARK: - Export Methods
    
    /// Export historical data to CSV format
    func exportToCSV(days: Int = 30) -> String {
        let history = loadHistory(days: days)
        var csv = "date,domain,time_seconds,time_formatted\n"
        
        for record in history {
            for (domain, ms) in record.domainTime {
                let seconds = ms / 1000.0
                let formatted = formatDuration(seconds)
                csv += "\(record.date),\(domain),\(Int(seconds)),\(formatted)\n"
            }
        }
        
        return csv
    }
    
    /// Export historical data to JSON format
    func exportToJSON(days: Int = 30) throws -> Data {
        let history = loadHistory(days: days)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(history)
    }
    
    /// Get export filename with date
    func exportFilename(format: ChromeTabManager.ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return "tabpilot_history_\(dateString).\(format.fileExtension)"
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Cleanup
    
    /// Remove records older than 30 days
    private func cleanupOldRecords(keepDays: Int = 30) {
        let fileManager = FileManager.default
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let files = try? fileManager.contentsOfDirectory(at: historyDirectoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files where file.pathExtension == "json" {
            let filename = file.deletingPathExtension().lastPathComponent
            guard let fileDate = formatter.date(from: filename) else { continue }
            
            if fileDate < cutoffDate {
                try? fileManager.removeItem(at: file)
                historicalCache.removeValue(forKey: filename)
            }
        }
    }
    
    // MARK: - Sparkline Data Methods
    
    /// Get daily time data for a specific URL over the last N days
    func getDailyTimeForURL(_ url: String, days: Int = 7) -> [(date: Date, seconds: Double)] {
        let history = getLastDays(days)
        let normalizedURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        var result: [(date: Date, seconds: Double)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for record in history {
            guard let recordDate = formatter.date(from: record.date) else { continue }
            
            var seconds: Double = 0
            // Check domain time since DailyTimeRecord doesn't have tabDetails
            if let urlComponents = URL(string: normalizedURL),
               let host = urlComponents.host {
                let domain = host.replacingOccurrences(of: "www.", with: "")
                seconds = (record.domainTime[domain] ?? 0) / 1000.0
            }
            
            result.append((date: recordDate, seconds: seconds))
        }
        
        return result.sorted { $0.date < $1.date }
    }
    
    /// Get daily time data for a specific domain over the last N days
    func getDailyTimeForDomain(_ domain: String, days: Int = 7) -> [(date: Date, seconds: Double)] {
        let history = getLastDays(days)
        let normalizedDomain = domain.replacingOccurrences(of: "www.", with: "")
        
        var result: [(date: Date, seconds: Double)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for record in history {
            guard let recordDate = formatter.date(from: record.date) else { continue }
            let seconds = (record.domainTime[normalizedDomain] ?? 0) / 1000.0
            result.append((date: recordDate, seconds: seconds))
        }
        
        return result.sorted { $0.date < $1.date }
    }
    
    // MARK: - Private Helpers
    
    private func getSortedHistory(limit: Int) -> [DailyTimeRecord] {
        let sorted = historicalCache.values.sorted { $0.date > $1.date }
        return Array(sorted.prefix(limit))
    }
}
