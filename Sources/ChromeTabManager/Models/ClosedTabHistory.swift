import Foundation

/// Lightweight in-memory + persisted history of recently closed tabs (beyond the 30s undo window).
struct ClosedTabHistory: Identifiable, Codable {
    let id: UUID
    let url: String
    let title: String
    let windowId: Int
    let closedAt: Date
    var restored: Bool
    
    init(url: String, title: String, windowId: Int) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.windowId = windowId
        self.closedAt = Date()
        self.restored = false
    }
    
    var domain: String {
        URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url
    }
    
    var ageDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: closedAt, relativeTo: Date())
    }
}
