import Foundation

@MainActor
protocol ScanTabsUseCaseProtocol {
    func execute(progress: @escaping @Sendable (Int, String) -> Void) async throws -> (tabs: [TabInfo], telemetry: ScanTelemetry)
}

@MainActor
protocol CloseTabsUseCaseProtocol {
    func execute(windowId: Int, targets: [(url: String, title: String)]) async -> (closed: Int, failed: Int, ambiguous: Int)
}

@MainActor
protocol ExportTabsUseCaseProtocol {
    func export(tabs: [TabInfo], format: ExportManager.ExportFormat) -> String
    func exportDuplicates(groups: [DuplicateGroup], format: ExportManager.ExportFormat) -> String
}

struct DefaultScanTabsUseCase: ScanTabsUseCaseProtocol {
    func execute(progress: @escaping @Sendable (Int, String) -> Void) async throws -> (tabs: [TabInfo], telemetry: ScanTelemetry) {
        try await ChromeController.shared.scanAllTabsFast(progress: progress)
    }
}

struct DefaultCloseTabsUseCase: CloseTabsUseCaseProtocol {
    func execute(windowId: Int, targets: [(url: String, title: String)]) async -> (closed: Int, failed: Int, ambiguous: Int) {
        await ChromeController.shared.closeTabsDeterministic(windowId: windowId, targets: targets)
    }
}

struct DefaultExportTabsUseCase: ExportTabsUseCaseProtocol {
    func export(tabs: [TabInfo], format: ExportManager.ExportFormat) -> String {
        ExportManager.export(tabs: tabs, format: format)
    }

    func exportDuplicates(groups: [DuplicateGroup], format: ExportManager.ExportFormat) -> String {
        ExportManager.exportDuplicates(groups: groups, format: format)
    }
}
