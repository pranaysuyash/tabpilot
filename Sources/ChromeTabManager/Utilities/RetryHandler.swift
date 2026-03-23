import Foundation

enum RetryError: LocalizedError {
    case maxAttemptsExceeded(attempts: Int, lastError: Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .maxAttemptsExceeded(let attempts, let lastError):
            return "Failed after \(attempts) attempts: \(lastError.localizedDescription)"
        case .cancelled:
            return "Retry operation was cancelled"
        }
    }
}

struct RetryConfig {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    static let `default` = RetryConfig(maxAttempts: 3, baseDelay: 1.0, maxDelay: 10.0)

    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
}

actor AsyncRetryHandler {
    static func retry<T>(
        config: RetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...config.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                if attempt < config.maxAttempts {
                    let delay = config.delay(for: attempt)
                    SecureLogger.debug("Retry attempt \(attempt)/\(config.maxAttempts) failed, retrying in \(delay)s: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw RetryError.maxAttemptsExceeded(attempts: config.maxAttempts, lastError: lastError!)
    }

    static func retryWithResult<T>(
        config: RetryConfig = .default,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        do {
            return .success(try await retry(config: config, operation: operation))
        } catch {
            return .failure(error)
        }
    }
}
