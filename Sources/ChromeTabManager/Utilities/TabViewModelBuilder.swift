import Foundation

typealias TabViewModel = TabManagerViewModel

final class TabViewModelBuilder {
    private var scanUseCase: ScanTabsUseCaseProtocol?
    private var closeUseCase: CloseTabsUseCaseProtocol?
    private var exportUseCase: ExportTabsUseCaseProtocol?
    private var eventBus: EventBus?

    func withScanUseCase(_ useCase: ScanTabsUseCaseProtocol) -> Self {
        self.scanUseCase = useCase
        return self
    }

    func withCloseUseCase(_ useCase: CloseTabsUseCaseProtocol) -> Self {
        self.closeUseCase = useCase
        return self
    }

    func withExportUseCase(_ useCase: ExportTabsUseCaseProtocol) -> Self {
        self.exportUseCase = useCase
        return self
    }

    func withEventBus(_ bus: EventBus) -> Self {
        self.eventBus = bus
        return self
    }

    @MainActor
    func build() -> TabViewModel {
        let finalScan = scanUseCase ?? DefaultScanTabsUseCase()
        let finalClose = closeUseCase ?? DefaultCloseTabsUseCase()
        let finalExport = exportUseCase ?? DefaultExportTabsUseCase()
        let finalBus = eventBus ?? .shared

        return TabViewModel(
            scanUseCase: finalScan,
            closeUseCase: finalClose,
            exportUseCase: finalExport,
            eventBus: finalBus
        )
    }
}
