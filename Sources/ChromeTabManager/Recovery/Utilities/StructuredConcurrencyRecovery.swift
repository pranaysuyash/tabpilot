import Foundation

enum TimeoutError: Error {
    case timedOut(seconds: TimeInterval)
}

/// Runs an async operation with a timeout and cancellation propagation.
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            let duration = UInt64(seconds * 1_000_000_000)
            try await Task.sleep(nanoseconds: duration)
            throw TimeoutError.timedOut(seconds: seconds)
        }

        defer { group.cancelAll() }
        guard let first = try await group.next() else {
            throw CancellationError()
        }
        return first
    }
}

extension Task where Failure == Never {
    /// Cancels a fire-and-forget task and awaits cooperative cleanup.
    func cancelAndWait() async {
        cancel()
        _ = await value
    }
}

/// Small helper for bounded parallel execution with TaskGroup.
func concurrentMap<Input: Sendable, Output: Sendable>(
    _ values: [Input],
    transform: @escaping @Sendable (Input) async throws -> Output
) async throws -> [Output] {
    try await withThrowingTaskGroup(of: (Int, Output).self) { group in
        for (index, value) in values.enumerated() {
            group.addTask {
                let output = try await transform(value)
                return (index, output)
            }
        }

        var ordered = Array<Output?>(repeating: nil, count: values.count)
        for try await (index, output) in group {
            ordered[index] = output
        }

        return ordered.compactMap { $0 }
    }
}
