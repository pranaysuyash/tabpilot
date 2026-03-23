import Foundation

protocol Repository: Actor {
    associatedtype Entity: Sendable

    func getAll() async throws -> [Entity]
    func get(byId id: String) async throws -> Entity?
    func save(_ entity: Entity) async throws
    func delete(_ id: String) async throws
}

actor SwiftDataRepository<Entity: Identifiable & Sendable>: Repository where Entity.ID == String {
    private var storage: [String: Entity] = [:]

    func getAll() async throws -> [Entity] {
        Array(storage.values)
    }

    func get(byId id: String) async throws -> Entity? {
        storage[id]
    }

    func save(_ entity: Entity) async throws {
        storage[entity.id] = entity
    }

    func delete(_ id: String) async throws {
        storage[id] = nil
    }
}

actor UserDefaultsRepository<Entity: Codable & Identifiable & Sendable>: Repository where Entity.ID == String {
    private let defaults: UserDefaults
    private let key: String
    private var storage: [String: Entity] = [:]

    init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
        self.storage = Self.loadFromDefaults(defaults: defaults, key: key)
    }

    func getAll() async throws -> [Entity] {
        Array(storage.values)
    }

    func get(byId id: String) async throws -> Entity? {
        storage[id]
    }

    func save(_ entity: Entity) async throws {
        storage[entity.id] = entity
        try persist()
    }

    func delete(_ id: String) async throws {
        storage[id] = nil
        try persist()
    }

    private nonisolated static func loadFromDefaults(defaults: UserDefaults, key: String) -> [String: Entity] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Entity].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(storage)
        defaults.set(data, forKey: key)
    }
}

actor FileRepository<Entity: Codable & Identifiable & Sendable>: Repository where Entity.ID == String {
    private let fileURL: URL
    private var storage: [String: Entity] = [:]

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.storage = Self.loadFromFile(fileURL: fileURL)
    }

    func getAll() async throws -> [Entity] {
        Array(storage.values)
    }

    func get(byId id: String) async throws -> Entity? {
        storage[id]
    }

    func save(_ entity: Entity) async throws {
        storage[entity.id] = entity
        try persist()
    }

    func delete(_ id: String) async throws {
        storage[id] = nil
        try persist()
    }

    private nonisolated static func loadFromFile(fileURL: URL) -> [String: Entity] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entity].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(storage)
        try data.write(to: fileURL, options: .atomic)
    }
}
