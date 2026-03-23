import Foundation

// RECOVERY ADDON: snapshot persistence for quick rollback and audit trails.
@MainActor
final class SnapshotManagerRecovery {
    struct Snapshot: Codable, Identifiable {
        let id: UUID
        let createdAt: Date
        let tabs: [TabInfoSnapshot]
    }

    struct TabInfoSnapshot: Codable {
        let id: String
        let windowId: Int
        let tabIndex: Int
        let title: String
        let url: String
    }

    private let key = "recovery.snapshot.latest"

    func saveSnapshot(from tabs: [TabInfo]) {
        let payload = Snapshot(
            id: UUID(),
            createdAt: Date(),
            tabs: tabs.map {
                TabInfoSnapshot(id: $0.id, windowId: $0.windowId, tabIndex: $0.tabIndex, title: $0.title, url: $0.url)
            }
        )
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    func loadSnapshot() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
