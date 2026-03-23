import Foundation

/// A saved session — a snapshot of tabs the user wants to preserve and reopen later.
struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var tabs: [SessionTab]
    let createdAt: Date
    var lastOpenedAt: Date?
    var notes: String
    
    init(id: UUID = UUID(), name: String, tabs: [SessionTab], notes: String = "") {
        self.id = id
        self.name = name
        self.tabs = tabs
        self.createdAt = Date()
        self.lastOpenedAt = nil
        self.notes = notes
    }
    
    var tabCount: Int { tabs.count }
    
    var domains: [String] {
        let allDomains = tabs.compactMap { URL(string: $0.url)?.host?.replacingOccurrences(of: "www.", with: "") }
        return Array(Set(allDomains)).sorted()
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var domainSummary: String {
        let d = domains
        if d.isEmpty { return "No tabs" }
        if d.count <= 3 { return d.joined(separator: ", ") }
        return "\(d.prefix(3).joined(separator: ", ")) +\(d.count - 3) more"
    }
}

/// A single tab entry in a saved session.
struct SessionTab: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let windowId: Int
    let tabIndex: Int
    
    init(tabInfo tab: TabInfo) {
        self.id = UUID()
        self.title = tab.title
        self.url = tab.url
        self.windowId = tab.windowId
        self.tabIndex = tab.tabIndex
    }
    
    init(id: UUID = UUID(), title: String, url: String, windowId: Int = 1, tabIndex: Int = 0) {
        self.id = id
        self.title = title
        self.url = url
        self.windowId = windowId
        self.tabIndex = tabIndex
    }
    
    var domain: String {
        URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url
    }
}

/// Store for saved sessions — persisted to UserDefaults.
@MainActor
class SessionStore: ObservableObject {
    static let shared = SessionStore()
    
    private let storageKey = DefaultsKeys.savedSessions
    
    @Published var sessions: [Session] = []
    
    private init() {
        load()
    }
    
    // MARK: - CRUD
    
    func saveCurrentTabs(_ tabs: [TabInfo], name: String, notes: String = "") {
        let sessionTabs = tabs.map { SessionTab(tabInfo: $0) }
        let session = Session(name: name, tabs: sessionTabs, notes: notes)
        sessions.insert(session, at: 0)
        persist()
    }
    
    func delete(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }
    
    func rename(_ session: Session, to newName: String) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx].name = newName
            persist()
        }
    }
    
    func markOpened(_ session: Session) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx].lastOpenedAt = Date()
            persist()
        }
    }
    
    // MARK: - Persistence
    
    private func load() {
        do {
            if let data = UserDefaults.standard.data(forKey: storageKey) {
                sessions = try JSONDecoder().decode([Session].self, from: data)
            }
        } catch {
            print("SessionStore: load failed: \(error)")
            sessions = []
        }
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("SessionStore: persist failed: \(error)")
        }
    }
}
