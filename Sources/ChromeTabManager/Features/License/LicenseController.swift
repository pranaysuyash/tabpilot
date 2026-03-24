import Foundation
import Combine

@MainActor
final class LicenseController: ObservableObject {
    @Published private(set) var isLicensed: Bool
    var isTrial: Bool { !isLicensed }
    
    var licenseType: String {
        isLicensed ? "Pro" : "Free"
    }
    
    var expirationDate: Date? { nil }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var freeClosesRemaining: Int

    private let licenseManager: LicenseManager
    private var cancellables: Set<AnyCancellable> = []

    init(licenseManager: LicenseManager = .shared) {
        self.licenseManager = licenseManager
        self.isLicensed = licenseManager.isLicensed
        self.freeClosesRemaining = licenseManager.freeClosesRemaining

        licenseManager.$isLicensed
            .combineLatest(licenseManager.$dailyCloseCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refreshFromManager()
            }
            .store(in: &cancellables)
    }
    
    func purchase() async {
        isLoading = true
        errorMessage = nil
        _ = await licenseManager.purchasePro()
        refreshFromManager()
        isLoading = false
    }
    
    func restore() async {
        isLoading = true
        errorMessage = nil
        _ = await licenseManager.restorePurchases()
        refreshFromManager()
        isLoading = false
    }
    
    func checkStatus() {
        refreshFromManager()
    }
    
    func canCloseTabs(requested: Int) -> Bool {
        if isLicensed { return true }
        return freeClosesRemaining >= requested
    }
    
    func recordCloses(_ count: Int) {
        licenseManager.recordCloses(count)
        refreshFromManager()
    }

    private func refreshFromManager() {
        isLicensed = licenseManager.isLicensed
        freeClosesRemaining = licenseManager.freeClosesRemaining
    }
}
