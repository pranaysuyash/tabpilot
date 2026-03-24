import Foundation

/// AsyncStream wrapper that centralizes continuation lifecycle and cleanup.
actor AsyncStreamMonitor<Element: Sendable> {
    private var continuation: AsyncStream<Element>.Continuation?
    private var isFinished = false

    func makeStream(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Element> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.finish() }
            }
        }
    }

    func yield(_ value: Element) {
        guard !isFinished else { return }
        continuation?.yield(value)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        continuation?.finish()
        continuation = nil
    }
}
