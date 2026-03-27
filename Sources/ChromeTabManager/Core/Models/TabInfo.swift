import Foundation

struct TabInfo: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let windowId: Int
    let tabIndex: Int
    var title: String
    var url: String
    let openedAt: Date
    /// Cached domain computed once at creation time to avoid repeated URL parsing
    let domain: String
    var profileName: String
    
    init(id: String, windowId: Int, tabIndex: Int, title: String, url: String, openedAt: Date, profileName: String = "Default") {
        self.id = id
        self.windowId = windowId
        self.tabIndex = tabIndex
        self.title = title
        self.url = url
        self.openedAt = openedAt
        self.domain = Self.computeDomain(from: url)
        self.profileName = profileName
    }
    
    /// Backward-compatible decoding for persisted data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        windowId = try container.decode(Int.self, forKey: .windowId)
        tabIndex = try container.decode(Int.self, forKey: .tabIndex)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(String.self, forKey: .url)
        openedAt = try container.decode(Date.self, forKey: .openedAt)
        if let cachedDomain = try? container.decode(String.self, forKey: .domain) {
            domain = cachedDomain
        } else {
            domain = Self.computeDomain(from: url)
        }
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName) ?? "Default"
    }
    
    var ageDescription: String {
        let seconds = Date().timeIntervalSince(openedAt)
        if seconds >= 86400 {
            return "\(Int(seconds / 86400))d ago"
        } else if seconds >= 3600 {
            return "\(Int(seconds / 3600))h ago"
        } else if seconds >= 60 {
            return "\(Int(seconds / 60))m ago"
        } else {
            return "\(Int(seconds))s ago"
        }
    }
    
    var ageColor: String {
        let seconds = Date().timeIntervalSince(openedAt)
        if seconds >= 86400 { return "red" }
        if seconds >= 3600 { return "yellow" }
        return "green"
    }

    private static func computeDomain(from url: String) -> String {
        if let components = URL(string: url), let host = components.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return String(url.prefix(50))
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, windowId, tabIndex, title, url, openedAt, domain, profileName
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(windowId, forKey: .windowId)
        try container.encode(tabIndex, forKey: .tabIndex)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encode(openedAt, forKey: .openedAt)
        try container.encode(domain, forKey: .domain)
        try container.encode(profileName, forKey: .profileName)
    }
    
    static func == (lhs: TabInfo, rhs: TabInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TabInfo {
    var isPruningCandidate: Bool {
        let age = Date().timeIntervalSince(openedAt)
        return age > 14400 && !isHighValueDomain
    }
    
    var isHighValueDomain: Bool {
        let highValue = ["github.com", "google.com", "stackoverflow.com", "linear.app", "figma.com"]
        return highValue.contains { matchesHighValueDomain(domain: domain, highValue: $0) }
    }

    private func matchesHighValueDomain(domain: String, highValue: String) -> Bool {
        let normalizedDomain = domain.lowercased()
        let normalizedHighValue = highValue.lowercased()
        return normalizedDomain == normalizedHighValue || normalizedDomain.hasSuffix("." + normalizedHighValue)
    }
}
