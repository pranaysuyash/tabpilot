import Foundation

enum ChromeError: Error, Sendable {
    case notRunning
    case appleScriptFailed(String)
    case timeout
    case ambiguousMatch(String)
}

extension ChromeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Google Chrome is not running"
        case .appleScriptFailed(let message):
            return "AppleScript error: \(message)"
        case .timeout:
            return "Operation timed out"
        case .ambiguousMatch(let message):
            return "Ambiguous match: \(message)"
        }
    }
}
