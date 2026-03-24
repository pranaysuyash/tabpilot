import Foundation

actor ChromeTabRepository: ChromeTabRepositoryProtocol {

    private let controller: ChromeController

    init(controller: ChromeController = .shared) {
        self.controller = controller
    }

    var isChromeRunning: Bool {
        get async {
            await controller.isChromeRunning()
        }
    }

    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> ScanResult {
        let (tabInfos, telemetry) = try await controller.scanAllTabsFast(progress: progress)

        let tabEntities = tabInfos.map { info in
            TabEntity(
                id: info.id,
                windowId: info.windowId,
                tabIndex: info.tabIndex,
                title: info.title,
                url: info.url,
                openedAt: info.openedAt
            )
        }

        let groupedByWindow = Dictionary(grouping: tabEntities) { $0.windowId }
        let windows = groupedByWindow.map { windowId, tabs in
            WindowEntity(
                windowId: windowId,
                tabCount: tabs.count,
                tabs: tabs.sorted { $0.tabIndex < $1.tabIndex },
                activeTabIndex: 0
            )
        }.sorted { $0.windowId < $1.windowId }

        let uniqueUrls = Set(tabEntities.map { $0.url }).count
        let stats = ScanStatsEntity(
            totalTabs: tabEntities.count,
            windowCount: windows.count,
            duplicateGroups: 0,
            wastedTabs: 0,
            uniqueUrls: uniqueUrls
        )

        let telemetryEntity = ScanTelemetryEntity(
            windowsAttempted: telemetry.windowsAttempted,
            windowsFailed: telemetry.windowsFailed,
            tabsFound: telemetry.tabsFound,
            errors: telemetry.errors,
            durationSeconds: telemetry.durationSeconds
        )

        return ScanResult(windows: windows, stats: stats, telemetry: telemetryEntity)
    }

    func closeTabs(windowId: Int, targets: [(url: String, title: String)]) async -> CloseResult {
        let result = await controller.closeTabsDeterministic(windowId: windowId, targets: targets)
        return CloseResult(
            closedCount: result.closed,
            failedIds: [],
            errors: result.ambiguous > 0 ? ["\(result.ambiguous) ambiguous tab(s) skipped"] : []
        )
    }

    func activateTab(windowId: Int, tabIndex: Int) async throws {
        try await controller.activateTab(windowId: windowId, tabIndex: tabIndex)
    }

    func openTab(windowId: Int, url: String) async -> Bool {
        await controller.openTab(windowId: windowId, url: url)
    }
}
