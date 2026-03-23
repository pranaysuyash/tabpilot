import Foundation

struct TabInfo: Identifiable, Hashable {
    let id: String
    let windowId: Int
    let tabIndex: Int
    var title: String
    var url: String
    let openedAt: Date
    
    var ageDescription: String {
        let seconds = Date().timeIntervalSince(openedAt)
        if seconds >= 86400 {
            return "\(Int(seconds / 86400))d ago"
        } else if seconds >= 3600 {
            return "\(Int(seconds / 3600))h ago"
        } else if seconds >= 60 {
            return "\(Int(seconds / 60))m ago"
        } else {
            return "\(Int(seconds))s ago"
        }
    }
    
    var ageColor: String {
        let seconds = Date().timeIntervalSince(openedAt)
        if seconds >= 86400 { return "red" }
        if seconds >= 3600 { return "yellow" }
        return "green"
    }
    
    var domain: String {
        guard let components = URL(string: url),
              let host = components.host else {
            return String(url.prefix(50))
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    static func == (lhs: TabInfo, rhs: TabInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct WindowInfo: Identifiable {
    let id = UUID()
    let windowId: Int
    let tabCount: Int
    var tabs: [TabInfo]
    var activeTabIndex: Int
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let normalizedUrl: String
    let displayUrl: String
    var tabs: [TabInfo]
    
    var oldestTab: TabInfo? {
        tabs.min { $0.openedAt < $1.openedAt }
    }
    
    var newestTab: TabInfo? {
        tabs.max { $0.openedAt < $1.openedAt }
    }
    
    var wastedCount: Int {
        max(0, tabs.count - 1)
    }
    
    var timeSpan: String {
        guard let oldest = oldestTab, let newest = newestTab else { return "" }
        let span = newest.openedAt.timeIntervalSince(oldest.openedAt)
        if span >= 3600 {
            return "\(Int(span / 3600))h apart"
        } else if span >= 60 {
            return "\(Int(span / 60))m apart"
        } else {
            return "\(Int(span))s apart"
        }
    }
}

struct ChromeInstance {
    let name: String
    let isRunning: Bool
    let windowCount: Int
    let totalTabs: Int
}

struct ScanStats {
    let totalTabs: Int
    let windowCount: Int
    let duplicateGroups: Int
    let wastedTabs: Int
    let uniqueUrls: Int
}

struct ScanTelemetry {
    let windowsAttempted: Int
    let windowsFailed: Int
    let tabsFound: Int
    let errors: [String]
    let durationSeconds: Double
}

struct DomainGroup: Identifiable {
    let id: String
    let domain: String
    let tabs: [TabInfo]

    init(domain: String, tabs: [TabInfo]) {
        self.id = domain
        self.domain = domain
        self.tabs = tabs
    }
}

struct HealthMetrics {
    let totalTabs: Int
    let duplicateCount: Int
    let domainCount: Int
    let averageTabsPerWindow: Double
    let oldestTabAge: TimeInterval
    let newestTabAge: TimeInterval
    let recommendedCleanupCount: Int

    static func compute(from tabs: [TabInfo], duplicates: [DuplicateGroup]) -> HealthMetrics {
        guard !tabs.isEmpty else {
            return HealthMetrics(
                totalTabs: 0,
                duplicateCount: 0,
                domainCount: 0,
                averageTabsPerWindow: 0,
                oldestTabAge: 0,
                newestTabAge: 0,
                recommendedCleanupCount: 0
            )
        }

        let now = Date()
        let uniqueDomains = Set(tabs.map { $0.domain })
        let windowIds = Set(tabs.map { $0.windowId })
        let ages = tabs.map { now.timeIntervalSince($0.openedAt) }

        return HealthMetrics(
            totalTabs: tabs.count,
            duplicateCount: duplicates.reduce(0) { $0 + $1.wastedCount },
            domainCount: uniqueDomains.count,
            averageTabsPerWindow: Double(tabs.count) / Double(max(1, windowIds.count)),
            oldestTabAge: ages.max() ?? 0,
            newestTabAge: ages.min() ?? 0,
            recommendedCleanupCount: duplicates.reduce(0) { $0 + $1.wastedCount }
        )
    }
}
