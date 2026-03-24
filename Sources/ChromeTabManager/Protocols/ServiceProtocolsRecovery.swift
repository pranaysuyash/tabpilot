import Foundation

// RECOVERY ADDON: additive service abstractions for future decomposition.
protocol URLNormalizingRecovery {
    func normalize(_ raw: String) -> String
}

struct URLNormalizerServiceRecovery: URLNormalizingRecovery {
    func normalize(_ raw: String) -> String {
        URLNormalizerRecovery.normalize(raw)
    }
}

// RECOVERY: Repository protocols for clean architecture decomposition.

protocol ChromeTabRepositoryProtocol: Actor {
    var isChromeRunning: Bool { get async }
    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> ScanResult
    func closeTabs(windowId: Int, targets: [(url: String, title: String)]) async -> CloseResult
    func activateTab(windowId: Int, tabIndex: Int) async throws
    func openTab(windowId: Int, url: String) async -> Bool
}

protocol TabTimestampRepositoryProtocol: Actor {
    func load() async -> [String: Date]
    func save(_ timestamps: [String: Date]) async
    func timestamp(for url: String) async -> Date?
    func setTimestamp(_ date: Date, for url: String) async
}

protocol ProtectedDomainRepositoryProtocol: Actor {
    func load() async -> [String]
    func save(_ domains: [String]) async
    func add(_ domain: String) async
    func remove(_ domain: String) async
    func isProtected(_ domain: String) async -> Bool
}
