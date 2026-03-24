import Foundation
import SwiftUI

@MainActor
final class ErrorPresenter: ObservableObject, Sendable {
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
