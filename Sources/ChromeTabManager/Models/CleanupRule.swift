import Foundation

struct CleanupRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var pattern: URLPattern
    var action: CleanupAction
    var enabled: Bool
    var maxAgeDays: Int?
    var matchCount: Int
    var lastAppliedAt: Date?

    enum CleanupAction: String, Codable, CaseIterable {
        case close = "Close"
        case archive = "Archive"
        case notify = "Notify"

        var icon: String {
            switch self {
            case .close: return "xmark.circle"
            case .archive: return "archivebox"
            case .notify: return "bell"
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        pattern: URLPattern,
        action: CleanupAction = .close,
        enabled: Bool = true,
        maxAgeDays: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.action = action
        self.enabled = enabled
        self.maxAgeDays = maxAgeDays
        self.matchCount = 0
        self.lastAppliedAt = nil
    }

    func matches(_ tab: TabInfo) -> Bool {
        guard enabled else { return false }
        return pattern.matches(tab.url)
    }
}
