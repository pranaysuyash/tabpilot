import Foundation

/// Store for saved cleanup rules — persisted to UserDefaults.
@MainActor
class CleanupRuleStore: ObservableObject {
    static let shared = CleanupRuleStore()
    
    private let storageKey = DefaultsKeys.cleanupRules
    
    @Published var rules: [CleanupRule] = []
    
    private init() {
        load()
        if rules.isEmpty { seedDefaults() }
    }
    
    // MARK: - CRUD
    
    func add(_ rule: CleanupRule) {
        rules.append(rule)
        persist()
    }
    
    func update(_ rule: CleanupRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
            persist()
        }
    }
    
    func delete(_ rule: CleanupRule) {
        rules.removeAll { $0.id == rule.id }
        persist()
    }
    
    func toggleEnabled(_ rule: CleanupRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx].enabled.toggle()
            persist()
        }
    }
    
    /// Find all tabs that match any enabled active rule.
    func matchingTabs(from tabs: [TabInfo]) -> [(tab: TabInfo, rule: CleanupRule)] {
        rules.filter(\.enabled).flatMap { rule in
            tabs.compactMap { tab in
                rule.matches(tab) ? (tab, rule) : nil
            }
        }
    }
    
    // MARK: - Persistence
    
    private func load() {
        do {
            if let data = UserDefaults.standard.data(forKey: storageKey) {
                rules = try JSONDecoder().decode([CleanupRule].self, from: data)
            }
        } catch {
            print("CleanupRuleStore: load failed: \(error)")
            rules = []
        }
    }
    
    func persist() {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("CleanupRuleStore: persist failed: \(error)")
        }
    }
    
    // MARK: - Default Rules
    
    private func seedDefaults() {
        // Seed a couple of sensible default examples
        let twitterRule = CleanupRule(
            name: "Twitter/X notifications",
            pattern: URLPattern(pattern: "*.twitter.com/*"),
            action: .archive,
            enabled: false
        )
        let youtubeRule = CleanupRule(
            name: "YouTube",
            pattern: URLPattern(pattern: "*.youtube.com/*"),
            action: .notify,
            enabled: false
        )
        rules = [twitterRule, youtubeRule]
        persist()
    }
}
