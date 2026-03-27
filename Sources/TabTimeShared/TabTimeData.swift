import Foundation

/// Shared data structure for tab time tracking data.
/// Used by both the main app (TabTimeStore) and the native messaging host (TabTimeHost).
public struct TabTimeData: Codable, Sendable {
    public var lastUpdated: Double
    public var date: String
    public var domainTime: [String: Double]
    public var tabDetails: [String: TabDetail]

    public init(
        lastUpdated: Double,
        date: String,
        domainTime: [String: Double],
        tabDetails: [String: TabDetail]
    ) {
        self.lastUpdated = lastUpdated
        self.date = date
        self.domainTime = domainTime
        self.tabDetails = tabDetails
    }

    public struct TabDetail: Codable, Sendable {
        public var url: String
        public var domain: String
        public var totalMs: Double

        public init(url: String, domain: String, totalMs: Double) {
            self.url = url
            self.domain = domain
            self.totalMs = totalMs
        }
    }
}
