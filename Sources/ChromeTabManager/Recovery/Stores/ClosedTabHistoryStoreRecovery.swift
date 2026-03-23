import Foundation

// RECOVERY ADDON: local persistence store for recently closed tabs.
@MainActor
final class ClosedTabHistoryStoreRecovery: ObservableObject {
    struct Item: Codable, Identifiable, Hashable {
        let id: UUID
        let windowId: Int
        let url: String
        let title: String
        let closedAt: Date

        init(id: UUID = UUID(), windowId: Int, url: String, title: String, closedAt: Date = Date()) {
            self.id = id
            self.windowId = windowId
            self.url = url
            self.title = title
            self.closedAt = closedAt
        }
    }

    @Published private(set) var items: [Item] = []
    private let key = "recovery.closedTabHistory"
    private let maxItems: Int

    init(maxItems: Int = 200) {
        self.maxItems = maxItems
        load()
    }

    func append(_ newItems: [Item]) {
        items = (newItems + items).prefix(maxItems).map { $0 }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Item].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }
}
