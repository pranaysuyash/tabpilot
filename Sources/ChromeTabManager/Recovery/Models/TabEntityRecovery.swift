import Foundation

/// Domain entity representing a browser tab
/// This is a pure data object with no presentation logic
struct TabEntity: Identifiable, Hashable, Codable {
    let id: String
    let windowId: Int
    let tabIndex: Int
    let title: String
    let url: String
    let openedAt: Date

    var domain: String {
        guard let components = URL(string: url),
              let host = components.host else {
            return String(url.prefix(50))
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    static func == (lhs: TabEntity, rhs: TabEntity) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Extension for creating stubs in tests
extension TabEntity {
    static func stub(
        id: String = UUID().uuidString,
        windowId: Int = 1,
        tabIndex: Int = 0,
        title: String = "Test Tab",
        url: String = "https://example.com",
        openedAt: Date = Date()
    ) -> TabEntity {
        TabEntity(
            id: id,
            windowId: windowId,
            tabIndex: tabIndex,
            title: title,
            url: url,
            openedAt: openedAt
        )
    }
}
