import Foundation

enum UserFacingError: LocalizedError {
    case chromeNotRunning
    case chromeTimeout
    case tabNotFound
    case tabCloseFailed(count: Int)
    case tabOpenFailed
    case scanFailed(reason: String)
    case archiveFailed
    case licenseVerificationFailed
    case networkError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .chromeNotRunning:
            return "Chrome is not running"
        case .chromeTimeout:
            return "Chrome is not responding"
        case .tabNotFound:
            return "Tab no longer exists"
        case .tabCloseFailed(let count):
            return "\(count) tab\(count == 1 ? "" : "s") failed to close"
        case .tabOpenFailed:
            return "Failed to open tab"
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .archiveFailed:
            return "Failed to save archive"
        case .licenseVerificationFailed:
            return "License verification failed"
        case .networkError:
            return "Network error occurred"
        case .unknown(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .chromeNotRunning:
            return "Please start Google Chrome and try again"
        case .chromeTimeout:
            return "Try restarting Chrome or waiting a moment and trying again"
        case .tabNotFound:
            return "The tab may have been closed already"
        case .tabCloseFailed:
            return "Try closing tabs individually"
        case .tabOpenFailed:
            return "Check if the URL is valid and Chrome is running"
        case .scanFailed:
            return "Try scanning again"
        case .archiveFailed:
            return "Check available disk space"
        case .licenseVerificationFailed:
            return "Check your internet connection"
        case .networkError:
            return "Check your internet connection"
        case .unknown:
            return "Try again later"
        }
    }

    var errorCode: String {
        switch self {
        case .chromeNotRunning: return "ERR-001"
        case .chromeTimeout: return "ERR-002"
        case .tabNotFound: return "ERR-003"
        case .tabCloseFailed: return "ERR-004"
        case .tabOpenFailed: return "ERR-005"
        case .scanFailed: return "ERR-006"
        case .archiveFailed: return "ERR-007"
        case .licenseVerificationFailed: return "ERR-008"
        case .networkError: return "ERR-009"
        case .unknown: return "ERR-999"
        }
    }
}

struct UserFacingErrorMessage: Identifiable {
    let id = UUID()
    let error: UserFacingError
    let timestamp: Date

    init(_ error: UserFacingError) {
        self.error = error
        self.timestamp = Date()
    }

    var displayMessage: String {
        error.errorDescription ?? "An unknown error occurred"
    }

    var suggestion: String? {
        error.recoverySuggestion
    }

    var code: String {
        error.errorCode
    }
}

@MainActor
final class ErrorPresenter: ObservableObject {
    static let shared = ErrorPresenter()

    @Published var currentError: UserFacingErrorMessage?
    @Published var errorHistory: [UserFacingErrorMessage] = []

    private init() {}

    func present(_ error: Error) {
        let userError = UserFacingError.from(error)
        let message = UserFacingErrorMessage(userError)

        currentError = message
        errorHistory.insert(message, at: 0)

        if errorHistory.count > 10 {
            errorHistory = Array(errorHistory.prefix(10))
        }

        SecureLogger.error("Error presented to user [\(userError.errorCode)]: \(userError.errorDescription ?? "")")
    }

    func present(_ userError: UserFacingError) {
        let message = UserFacingErrorMessage(userError)

        currentError = message
        errorHistory.insert(message, at: 0)

        if errorHistory.count > 10 {
            errorHistory = Array(errorHistory.prefix(10))
        }

        SecureLogger.error("Error presented to user [\(userError.errorCode)]: \(userError.errorDescription ?? "")")
    }

    func dismiss() {
        currentError = nil
    }

    func clearHistory() {
        errorHistory.removeAll()
    }
}

extension UserFacingError {
    static func from(_ error: Error) -> UserFacingError {
        if let chromeError = error as? ChromeError {
            switch chromeError {
            case .notRunning:
                return .chromeNotRunning
            case .timeout:
                return .chromeTimeout
            case .appleScriptFailed:
                return .unknown(error)
            case .ambiguousMatch:
                return .tabNotFound
            }
        }

        return .unknown(error)
    }
}
