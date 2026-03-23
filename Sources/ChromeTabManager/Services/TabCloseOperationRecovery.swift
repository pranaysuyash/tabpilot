import Foundation

// RECOVERY ADDON: encapsulates close operation intent for auditing/retry.
struct TabCloseOperationRecovery: Codable, Identifiable, Hashable {
    let id: UUID
    let tabId: String
    let windowId: Int
    let tabIndex: Int
    let url: String
    let title: String
    let createdAt: Date

    init(id: UUID = UUID(), tab: TabInfo, createdAt: Date = Date()) {
        self.id = id
        self.tabId = tab.id
        self.windowId = tab.windowId
        self.tabIndex = tab.tabIndex
        self.url = tab.url
        self.title = tab.title
        self.createdAt = createdAt
    }
}
