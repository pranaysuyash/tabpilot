import Foundation
import StoreKit

// MARK: - License Manager
//
// Simple model: User purchases once, gets lifetime access.
// No account needed - App Store handles receipt verification.

@MainActor
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isPro = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let isProKey = "isProPurchased"
    
    private init() {
        isPro = userDefaults.bool(forKey: isProKey)
    }
    
    func purchasePro() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        // Simulate purchase in debug
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        setProPurchased()
        isLoading = false
        return true
        #else
        // Production: Use StoreKit to purchase
        do {
            let product = try await Product.products(for: ["com.pranay.chrometabmanager.pro"]).first
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
                setProPurchased()
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
        setProPurchased()
        isLoading = false
        return isPro
        #else
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == "com.pranay.chrometabmanager.pro" {
                        setProPurchased()
                        isLoading = false
                        return true
                    }
                }
            }
            isLoading = false
            return isPro
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return isPro
        }
        #endif
    }
    
    private func setProPurchased() {
        isPro = true
        userDefaults.set(true, forKey: isProKey)
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

// MARK: - Paywall Copy

struct PaywallCopy {
    static let title = "Unlock Chrome Tab Manager Pro"
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
