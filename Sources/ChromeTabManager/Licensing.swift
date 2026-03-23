import Foundation
import StoreKit

@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var isLicensed = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var dailyCloseCount = 0

    private let userDefaults = UserDefaults.standard
    private let licenseKey = "isProPurchased"
    private let dailyCloseCountKey = "dailyCloseCount"
    private let dailyCloseDateKey = "dailyCloseDate"

    var isPro: Bool { isLicensed }

    let freeDailyCloseLimit = 10

    private init() {
        isLicensed = userDefaults.bool(forKey: licenseKey)
        refreshDailyState()
    }

    func purchasePro() async -> Bool {
        isLoading = true
        errorMessage = nil

        #if DEBUG
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        setLicensed()
        isLoading = false
        return true
        #else
        do {
            let product = try await Product.products(for: ["com.pranay.chrometabmanager.lifetime"]).first
            guard let product = product else {
                errorMessage = "Product not found"
                isLoading = false
                return false
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setLicensed()
                isLoading = false
                return true
            case .userCancelled:
                isLoading = false
                return false
            case .pending:
                errorMessage = "Purchase pending"
                isLoading = false
                return false
            @unknown default:
                errorMessage = "Unknown error"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
        #endif
    }

    func restorePurchases() async -> Bool {
        isLoading = true

        #if DEBUG
        try? await Task.sleep(nanoseconds: 500_000_000)
        setLicensed()
        isLoading = false
        return isLicensed
        #else
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == "com.pranay.chrometabmanager.lifetime" || transaction.productID == "com.pranay.chrometabmanager.pro" {
                        setLicensed()
                        isLoading = false
                        return true
                    }
                }
            }
            isLoading = false
            return isLicensed
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return isLicensed
        }
        #endif
    }

    private func setLicensed() {
        isLicensed = true
        userDefaults.set(true, forKey: licenseKey)
    }

    var freeClosesRemaining: Int {
        refreshDailyState()
        guard !isPro else { return .max }
        return max(0, freeDailyCloseLimit - dailyCloseCount)
    }

    func canCloseTabs(requested: Int) -> Bool {
        guard requested > 0 else { return true }
        if isPro { return true }
        return freeClosesRemaining >= requested
    }

    func recordCloses(_ count: Int) {
        guard count > 0 else { return }
        refreshDailyState()

        if isPro {
            dailyCloseCount += count
        } else {
            dailyCloseCount = min(freeDailyCloseLimit, dailyCloseCount + count)
        }

        userDefaults.set(dailyCloseCount, forKey: dailyCloseCountKey)
    }

    private func refreshDailyState() {
        let today = Self.dayStamp(for: Date())
        let savedDay = userDefaults.string(forKey: dailyCloseDateKey)

        if savedDay != today {
            dailyCloseCount = 0
            userDefaults.set(0, forKey: dailyCloseCountKey)
            userDefaults.set(today, forKey: dailyCloseDateKey)
        } else {
            dailyCloseCount = userDefaults.integer(forKey: dailyCloseCountKey)
        }
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    #if !DEBUG
    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified:
            throw LicenseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    #endif
}

enum LicenseError: Error {
    case failedVerification
    case productNotFound
}

struct PaywallCopy {
    static let title = "Unlock Chrome Tab Manager"
    static let subtitle = "Buy once. Use forever."
    static let price = "$19.99"

    static let features = [
        "Unlimited tab cleanup",
        "Review changes before closing",
        "Undo accidental closes",
        "Protect important domains",
        "Advanced filters and search",
        "Priority support"
    ]

    static let callToAction = "Upgrade Now"
    static let restoreButton = "Restore Purchases"
}
