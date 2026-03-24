import Foundation

protocol Event: Sendable {}

struct TabClosedEvent: Event, Sendable {
    let tabId: String
    let timestamp: Date
}

struct ArchiveCreatedEvent: Event, Sendable {
    let archiveId: String
    let tabCount: Int
}

@MainActor
final class EventBus: Sendable {
    static let shared = EventBus()

    private var subscribers: [ObjectIdentifier: [UUID: (any Event) -> Void]] = [:]

    private init() {}

    @discardableResult
    func subscribe<T: Event>(to eventType: T.Type, handler: @escaping (T) -> Void) -> UUID {
        let token = UUID()
        let key = ObjectIdentifier(eventType)
        let wrapped: (any Event) -> Void = { event in
            guard let typed = event as? T else { return }
            handler(typed)
        }
        subscribers[key, default: [:]][token] = wrapped
        return token
    }

    func unsubscribe<T: Event>(from eventType: T.Type, token: UUID) {
        let key = ObjectIdentifier(eventType)
        subscribers[key]?[token] = nil
        if subscribers[key]?.isEmpty == true {
            subscribers[key] = nil
        }
    }

    func publish(_ event: any Event) {
        let key = ObjectIdentifier(type(of: event))
        guard let handlers = subscribers[key]?.values else { return }
        handlers.forEach { $0(event) }
    }
}
