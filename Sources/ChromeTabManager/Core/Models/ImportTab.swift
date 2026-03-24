import Foundation
import SwiftUI

struct ImportTab: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: String
    let source: String

    init(title: String, url: String, source: String = "import") {
        self.id = UUID().uuidString
        self.title = title.isEmpty ? "Untitled" : title
        self.url = url
        self.source = source
    }
}

struct DomainGroup: Identifiable, Sendable {
    let id: String
    let domain: String
    let tabs: [TabInfo]

    init(domain: String, tabs: [TabInfo]) {
        self.id = domain
        self.domain = domain
        self.tabs = tabs
    }
}

struct HealthMetrics: Sendable {
    let totalTabs: Int
    let duplicateCount: Int
    let domainCount: Int
    let averageTabsPerWindow: Double
    let oldestTabAge: TimeInterval
    let newestTabAge: TimeInterval
    let recommendedCleanupCount: Int

    var score: Int {
        guard totalTabs > 0 else { return 100 }
        let duplicateRatio = Double(duplicateCount) / Double(totalTabs)
        let memoryPressure = min(1.0, Double(totalTabs) / 500.0)
        let windowSpread = min(1.0, averageTabsPerWindow / 50.0)
        let raw = 100.0 - (duplicateRatio * 50.0) - (memoryPressure * 30.0) - (windowSpread * 20.0)
        return max(0, min(100, Int(raw)))
    }

    var statusColor: Color {
        switch score {
        case 80...: return .green
        case 50...: return .orange
        default:    return .red
        }
    }

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
