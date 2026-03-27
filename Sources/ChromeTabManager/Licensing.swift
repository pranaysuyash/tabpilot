import Foundation

// MARK: - Always-Licensed Mode
// Payment happens on landing page ($19.99 to download)
// App is fully functional once downloaded

@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    /// Always returns true - app is always licensed
    var isLicensed: Bool { true }
    
    /// Always returns true - all features available
    var isPro: Bool { true }
    
    /// No limits on tab closes
    let freeDailyCloseLimit = Int.max

    private init() {}

    /// Always returns true - purchase happens on landing page
    func purchasePro() async -> Bool { true }

    /// Always returns true - no in-app purchase needed
    func restorePurchases() async -> Bool { true }

    /// Always returns max - no limits
    var freeClosesRemaining: Int { .max }

    /// Always returns true - no restrictions
    func canCloseTabs(requested: Int) -> Bool { true }

    /// No-op - tracking not needed in always-licensed mode
    func recordCloses(_ count: Int) {}
}

enum LicenseError: Error {
    case failedVerification
    case productNotFound
}
