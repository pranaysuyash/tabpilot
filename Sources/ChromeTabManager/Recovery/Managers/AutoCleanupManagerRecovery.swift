import Foundation

// RECOVERY ADDON: additive manager that proposes tabs to close from duplicate groups.
@MainActor
final class AutoCleanupManagerRecovery {
    private let normalizer: URLNormalizingRecovery

    init(normalizer: URLNormalizingRecovery = URLNormalizerServiceRecovery()) {
        self.normalizer = normalizer
    }

    func proposedClosures(from groups: [DuplicateGroup], protectedDomains: [String]) -> [TabInfo] {
        let protected = Set(protectedDomains.map { $0.lowercased() })
        return groups.flatMap { group -> [TabInfo] in
            let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
            guard sorted.count > 1 else { return [] }
            return sorted.dropFirst().filter { tab in
                let host = URL(string: normalizer.normalize(tab.url))?.host?.lowercased() ?? ""
                return !protected.contains(where: { host.contains($0) || $0.contains(host) })
            }
        }
    }
}
