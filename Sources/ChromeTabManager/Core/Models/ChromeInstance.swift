import Foundation

struct ChromeInstance: Sendable {
    let name: String
    let isRunning: Bool
    let windowCount: Int
    let totalTabs: Int
}

struct ScanStats: Sendable {
    let totalTabs: Int
    let windowCount: Int
    let duplicateGroups: Int
    let wastedTabs: Int
    let uniqueUrls: Int
}

struct ScanTelemetry: Sendable {
    let windowsAttempted: Int
    let windowsFailed: Int
    let tabsFound: Int
    let errors: [String]
    let durationSeconds: Double
}
