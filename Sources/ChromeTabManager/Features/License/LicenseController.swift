import Foundation

@MainActor
@Observable
final class LicenseController {
    var isLicensed: Bool { LicenseManager.shared.isLicensed }
    var isTrial: Bool { !isLicensed }
    
    var licenseType: String {
        isLicensed ? "Pro" : "Free"
    }
    
    var expirationDate: Date? { nil }
    var isLoading = false
    var errorMessage: String?
    var freeClosesRemaining: Int { LicenseManager.shared.freeClosesRemaining }
    
    func purchase() async {
        isLoading = true
        errorMessage = nil
        await LicenseManager.shared.purchasePro()
        isLoading = false
    }
    
    func restore() async {
        isLoading = true
        errorMessage = nil
        await LicenseManager.shared.restorePurchases()
        isLoading = false
    }
    
    func checkStatus() {
        LicenseManager.shared.objectWillChange.send()
    }
    
    func canCloseTabs(requested: Int) -> Bool {
        if isLicensed { return true }
        return freeClosesRemaining >= requested
    }
    
    func recordCloses(_ count: Int) {
        LicenseManager.shared.recordCloses(count)
    }
}
