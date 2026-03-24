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
        Task {
            await SecurityAuditLogger.shared.log(
                category: "licensing",
                action: "purchase_started",
                severity: .info
            )
        }

        #if DEBUG
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        setLicensed()
        Task {
            await SecurityAuditLogger.shared.log(
                category: "licensing",
                action: "purchase_completed",
                severity: .info,
                details: ["build": "debug"]
            )
        }
        isLoading = false
        return true
        #else
        do {
            let product = try await Product.products(for: ["com.pranay.chrometabmanager.lifetime"]).first
            guard let product = product else {
                errorMessage = "Product not found"
                Task {
                    await SecurityAuditLogger.shared.log(
                        category: "licensing",
                        action: "purchase_product_not_found",
                        severity: .warning
                    )
                }
                isLoading = false
                return false
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setLicensed()
                Task {
                    await SecurityAuditLogger.shared.log(
                        category: "licensing",
                        action: "purchase_completed",
                        severity: .info,
                        details: ["productId": product.id]
                    )
                }
                isLoading = false
                return true
            case .userCancelled:
                Task {
                    await SecurityAuditLogger.shared.log(
                        category: "licensing",
                        action: "purchase_cancelled",
                        severity: .info
                    )
                }
                isLoading = false
                return false
            case .pending:
                errorMessage = "Purchase pending"
                Task {
                    await SecurityAuditLogger.shared.log(
                        category: "licensing",
                        action: "purchase_pending",
                        severity: .info
                    )
                }
                isLoading = false
                return false
            @unknown default:
                errorMessage = "Unknown error"
                Task {
                    await SecurityAuditLogger.shared.log(
                        category: "licensing",
                        action: "purchase_unknown_result",
                        severity: .warning
                    )
                }
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            Task {
                await SecurityAuditLogger.shared.log(
                    category: "licensing",
                    action: "purchase_failed",
                    severity: .warning,
                    details: ["error": error.localizedDescription]
                )
            }
            isLoading = false
            return false
        }
        #endif
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        Task {
            await SecurityAuditLogger.shared.log(
                category: "licensing",
                action: "restore_started",
                severity: .info
            )
        }

        #if DEBUG
        try? await Task.sleep(nanoseconds: 500_000_000)
        setLicensed()
        Task {
            await SecurityAuditLogger.shared.log(
                category: "licensing",
                action: "restore_completed",
                severity: .info,
                details: ["build": "debug"]
            )
        }
        isLoading = false
        return isLicensed
        #else
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == "com.pranay.chrometabmanager.lifetime" || transaction.productID == "com.pranay.chrometabmanager.pro" {
                        setLicensed()
                        Task {
                            await SecurityAuditLogger.shared.log(
                                category: "licensing",
                                action: "restore_completed",
                                severity: .info,
                                details: ["productId": transaction.productID]
                            )
                        }
                        isLoading = false
                        return true
                    }
                }
            }
            Task {
                await SecurityAuditLogger.shared.log(
                    category: "licensing",
                    action: "restore_no_entitlement",
                    severity: .info
                )
            }
            isLoading = false
            return isLicensed
        } catch {
            errorMessage = error.localizedDescription
            Task {
                await SecurityAuditLogger.shared.log(
                    category: "licensing",
                    action: "restore_failed",
                    severity: .warning,
                    details: ["error": error.localizedDescription]
                )
            }
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
        Task {
            await SecurityAuditLogger.shared.log(
                category: "licensing",
                action: "close_usage_recorded",
                severity: .info,
                details: [
                    "count": String(count),
                    "dailyCloseCount": String(dailyCloseCount),
                    "isPro": String(isPro)
                ]
            )
        }
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
    static let title = "Unlock TabPilot"
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
