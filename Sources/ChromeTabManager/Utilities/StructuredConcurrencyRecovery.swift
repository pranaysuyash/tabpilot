import Foundation

enum TimeoutError: Error {
    case timedOut(seconds: TimeInterval)
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
