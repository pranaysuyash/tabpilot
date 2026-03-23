import Foundation

// RECOVERY ADDON: additive URL pattern model for include/exclude policy.
struct URLPatternRecovery: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case include
        case exclude
    }

    let id: UUID
    var kind: Kind
    var pattern: String
    var enabled: Bool

    init(id: UUID = UUID(), kind: Kind, pattern: String, enabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.pattern = pattern
        self.enabled = enabled
    }
}
