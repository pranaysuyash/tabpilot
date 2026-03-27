import Foundation

/// Represents a single day's time tracking record.
public struct DailyTimeRecord: Codable, Sendable, Identifiable {
    public let id: String
    public let date: String
    public let totalActiveTimeMs: Double
    public let domainTime: [String: Double]
    public let tabCount: Int
    public let savedAt: Date
    
    public init(
        date: String,
        totalActiveTimeMs: Double,
        domainTime: [String: Double],
        tabCount: Int,
        savedAt: Date = Date()
    ) {
        self.id = date
        self.date = date
        self.totalActiveTimeMs = totalActiveTimeMs
        self.domainTime = domainTime
        self.tabCount = tabCount
        self.savedAt = savedAt
    }
    
    public var totalActiveTimeSeconds: Double {
        totalActiveTimeMs / 1000.0
    }
    
    public func topDomains(limit: Int = 10) -> [(domain: String, seconds: Double)] {
        domainTime
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (domain: $0.key, seconds: $0.value / 1000.0) }
    }
}

/// Aggregate statistics across multiple days
public struct HistoricalStatistics: Sendable {
    public let days: [DailyTimeRecord]
    public let dateRange: (start: Date, end: Date)
    
    public init(days: [DailyTimeRecord]) {
        self.days = days.sorted { $0.date < $1.date }
        let dates = days.compactMap { Self.parseDate($0.date) }
        if let minDate = dates.min(), let maxDate = dates.max() {
            self.dateRange = (start: minDate, end: maxDate)
        } else {
            self.dateRange = (start: Date(), end: Date())
        }
    }
    
    public var totalTimeSeconds: Double {
        days.reduce(0) { $0 + $1.totalActiveTimeSeconds }
    }
    
    public var averageDailyTimeSeconds: Double {
        guard !days.isEmpty else { return 0 }
        return totalTimeSeconds / Double(days.count)
    }
    
    public var aggregatedDomainTime: [(domain: String, seconds: Double)] {
        var aggregated: [String: Double] = [:]
        for day in days {
            for (domain, ms) in day.domainTime {
                aggregated[domain, default: 0] += ms / 1000.0
            }
        }
        return aggregated
            .sorted { $0.value > $1.value }
            .map { (domain: $0.key, seconds: $0.value) }
    }
    
    public var trend: Trend {
        guard days.count >= 2 else { return .noData }
        let sortedDays = days.sorted { $0.date < $1.date }
        let lastDay = sortedDays.last!.totalActiveTimeSeconds
        let previousDays = sortedDays.dropLast()
        guard !previousDays.isEmpty else { return .noData }
        let averagePrevious = previousDays.reduce(0.0) { $0 + $1.totalActiveTimeSeconds } / Double(previousDays.count)
        
        guard averagePrevious > 0 else { return .noData }
        let percentChange = ((lastDay - averagePrevious) / averagePrevious) * 100
        
        if percentChange > 10 {
            return .increasing(percentChange)
        } else if percentChange < -10 {
            return .decreasing(percentChange)
        } else {
            return .stable(percentChange)
        }
    }
    
    public enum Trend: Sendable {
        case increasing(Double)
        case decreasing(Double)
        case stable(Double)
        case noData
        
        public var description: String {
            switch self {
            case .increasing(let pct):
                return "↑ \(String(format: "%.1f", abs(pct)))%"
            case .decreasing(let pct):
                return "↓ \(String(format: "%.1f", abs(pct)))%"
            case .stable(let pct):
                return "→ \(String(format: "%.1f", abs(pct)))%"
            case .noData:
                return "-"
            }
        }
        
        public var color: String {
            switch self {
            case .increasing:
                return "red"
            case .decreasing:
                return "green"
            case .stable:
                return "gray"
            case .noData:
                return "gray"
            }
        }
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
