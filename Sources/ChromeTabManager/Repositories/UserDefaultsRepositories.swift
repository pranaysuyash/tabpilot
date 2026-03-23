import Foundation

actor UserDefaultsTabTimestampRepository: TabTimestampRepositoryProtocol {

    private let defaults: UserDefaults
    private let key = "tabTimestamps"
    private var cache: [String: Date]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() async -> [String: Date] {
        if let cached = cache {
            return cached
        }

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }

        cache = decoded
        return decoded
    }

    func save(_ timestamps: [String: Date]) async {
        cache = timestamps
        if let encoded = try? JSONEncoder().encode(timestamps) {
            defaults.set(encoded, forKey: key)
        }
    }

    func timestamp(for url: String) async -> Date? {
        let timestamps = await load()
        return timestamps[url]
    }

    func setTimestamp(_ date: Date, for url: String) async {
        var timestamps = await load()
        timestamps[url] = date
        await save(timestamps)
    }
}

actor UserDefaultsProtectedDomainRepository: ProtectedDomainRepositoryProtocol {

    private let defaults: UserDefaults
    private let key = "protectedDomains"
    private var cache: [String]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() async -> [String] {
        if let cached = cache {
            return cached
        }

        let domains = defaults.stringArray(forKey: key) ?? []
        cache = domains
        return domains
    }

    func save(_ domains: [String]) async {
        cache = domains
        defaults.set(domains, forKey: key)
    }

    func add(_ domain: String) async {
        var domains = await load()
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty && !domains.contains(trimmed) else { return }
        domains.append(trimmed)
        await save(domains)
    }

    func remove(_ domain: String) async {
        var domains = await load()
        domains.removeAll { $0 == domain }
        await save(domains)
    }

    func isProtected(_ domain: String) async -> Bool {
        let domains = await load()
        let lowercasedDomain = domain.lowercased()
        return domains.contains { lowercasedDomain.contains($0) || $0.contains(lowercasedDomain) }
    }
}
