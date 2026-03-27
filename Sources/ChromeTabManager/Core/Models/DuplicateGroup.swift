import Foundation

struct DuplicateGroup: Identifiable, Sendable {
    var id: String { normalizedUrl }
    let normalizedUrl: String
    let displayUrl: String
    var tabs: [TabInfo]
    
    /// Pre-computed at creation time to avoid O(n) min scan on every view access
    let oldestTab: TabInfo?
    /// Pre-computed at creation time to avoid O(n) max scan on every view access
    let newestTab: TabInfo?
    
    init(normalizedUrl: String, displayUrl: String, tabs: [TabInfo]) {
        self.normalizedUrl = normalizedUrl
        self.displayUrl = displayUrl
        self.tabs = tabs
        self.oldestTab = tabs.min { $0.openedAt < $1.openedAt }
        self.newestTab = tabs.max { $0.openedAt < $1.openedAt }
    }
    
    var wastedCount: Int {
        max(0, tabs.count - 1)
    }
    
    var timeSpan: String {
        guard let oldest = oldestTab, let newest = newestTab else { return "" }
        let span = newest.openedAt.timeIntervalSince(oldest.openedAt)
        if span >= 3600 {
            return "\(Int(span / 3600))h apart"
        } else if span >= 60 {
            return "\(Int(span / 60))m apart"
        } else {
            return "\(Int(span))s apart"
        }
    }
}
