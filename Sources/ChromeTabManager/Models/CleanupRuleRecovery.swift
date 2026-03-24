import Foundation

// RECOVERY ADDON: additive cleanup rule model (v1) independent of existing models.
struct CleanupRuleRecovery: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var urlContains: String
    var keepCount: Int
    var enabled: Bool

    init(id: UUID = UUID(), name: String, urlContains: String, keepCount: Int = 1, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.urlContains = urlContains
        self.keepCount = max(0, keepCount)
        self.enabled = enabled
    }
}
