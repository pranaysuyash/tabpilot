import Foundation

/// Protocol for scanning Chrome tabs.
protocol ChromeScannerProtocol {
    func scanAllTabsFast(progress: @escaping @Sendable (Int, String) -> Void) async throws -> (tabs: [TabInfo], telemetry: ScanTelemetry)
    func isChromeRunning() async -> Bool
    func getWindowCount() async throws -> Int
}

/// Protocol for closing and activating Chrome tabs.
protocol ChromeTabControllerProtocol {
    func closeTabsDeterministic(windowId: Int, targets: [(url: String, title: String)]) async -> (closed: Int, failed: Int, ambiguous: Int)
    func openTab(windowId: Int, url: String) async -> Bool
    func activateTab(windowId: Int, tabIndex: Int) async throws
    func findTabIndex(windowId: Int, url: String, title: String?) async -> Int?
}

/// Protocol for querying Chrome Chrome instances.
protocol ChromeInstanceProtocol {
    func getInstances(knownTabCount: Int) async -> [ChromeInstance]
}

/// Protocol for persisting tab timestamps.
protocol TimestampStoreProtocol {
    func firstSeenDate(windowId: Int, tabIndex: Int, url: String) -> Date?
    func record(windowId: Int, tabIndex: Int, url: String, date: Date)
    func prune(to currentKeys: Set<String>)
}

/// Protocol for license checking.
protocol LicenseProtocol {
    var isPro: Bool { get }
}

extension LicenseManager: LicenseProtocol {}
