import Foundation

/// Options for how to restore a session
enum RestoreOptions: String, CaseIterable, Identifiable {
    case addToOpen = "Add to Open"
    case newWindow = "New Window"
    case replaceOpen = "Replace Open"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .addToOpen: return "plus.circle"
        case .newWindow: return "rectangle.portrait.on.rectangle.portrait.angled"
        case .replaceOpen: return "arrow.triangle.2.circlepath"
        }
    }
    
    var description: String {
        switch self {
        case .addToOpen: return "Adds tabs to your existing Chrome tabs"
        case .newWindow: return "Opens session in a new Chrome window"
        case .replaceOpen: return "Closes all open tabs, then opens session"
        }
    }
}

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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let sessionTabs = tabs.map { SessionTab(tabInfo: $0) }
        let session = Session(name: trimmedName, tabs: sessionTabs, notes: notes)

        // Handle name collision: overwrite existing session with same name (case-insensitive)
        if let existingIdx = sessions.firstIndex(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            sessions[existingIdx] = session
        } else {
            sessions.insert(session, at: 0)
        }
        persist()
    }

    func sessionExists(withName name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return sessions.contains { $0.name.lowercased() == trimmed }
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

    // MARK: - Import Helpers

    func replaceAll(_ newSessions: [Session]) {
        sessions = newSessions
        persist()
    }

    func appendSessions(_ newSessions: [Session]) {
        guard !newSessions.isEmpty else { return }
        sessions.append(contentsOf: newSessions)
        persist()
    }
    
    /// Restore a session with the given option.
    /// Returns the count of successfully opened tabs.
    func restoreSession(_ session: Session, option: RestoreOptions) async -> Int {
        guard await ChromeController.shared.isChromeRunning() else { return 0 }
        
        switch option {
        case .addToOpen:
            return await restoreToExistingWindow(session)
        case .newWindow:
            return await restoreToNewWindow(session)
        case .replaceOpen:
            return await restoreWithReplace(session)
        }
    }
    
    private func restoreToExistingWindow(_ session: Session) async -> Int {
        let windowCount = (try? await ChromeController.shared.getWindowCount()) ?? 0
        guard windowCount > 0 else { return 0 }
        
        var restoredCount = 0
        for tab in session.tabs {
            let success = await ChromeController.shared.openTab(windowId: 1, url: tab.url)
            if success { restoredCount += 1 }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return restoredCount
    }
    
    private func restoreToNewWindow(_ session: Session) async -> Int {
        let newWindowId = await ChromeController.shared.createNewWindow()
        guard let windowId = newWindowId, windowId > 0 else { return 0 }
        
        var restoredCount = 0
        for tab in session.tabs {
            let success = await ChromeController.shared.openTab(windowId: windowId, url: tab.url)
            if success { restoredCount += 1 }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return restoredCount
    }
    
    private func restoreWithReplace(_ session: Session) async -> Int {
        guard await ChromeController.shared.closeAllTabs() else { return 0 }
        
        let windowCount = (try? await ChromeController.shared.getWindowCount()) ?? 0
        guard windowCount > 0 else { return 0 }
        
        var restoredCount = 0
        for tab in session.tabs {
            let success = await ChromeController.shared.openTab(windowId: 1, url: tab.url)
            if success { restoredCount += 1 }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return restoredCount
    }
    
    // MARK: - Persistence
    
    private func load() {
        do {
            if let data = UserDefaults.standard.data(forKey: storageKey) {
                sessions = try JSONDecoder().decode([Session].self, from: data)
            }
        } catch {
            SecureLogger.error("SessionStore: load failed: \(error.localizedDescription)")
            sessions = []
        }
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            SecureLogger.error("SessionStore: persist failed: \(error.localizedDescription)")
        }
    }
}
