import Foundation
import SwiftUI

struct TabInfo: Identifiable, Hashable, Sendable {
    let id: String
    let windowId: Int
    let tabIndex: Int
    var title: String
    var url: String
    let openedAt: Date
    
    private let _cachedDomain: String
    
    init(id: String, windowId: Int, tabIndex: Int, title: String, url: String, openedAt: Date) {
        self.id = id
        self.windowId = windowId
        self.tabIndex = tabIndex
        self.title = title
        self.url = url
        self.openedAt = openedAt
        
        if let components = URL(string: url),
           let host = components.host {
            self._cachedDomain = host.replacingOccurrences(of: "www.", with: "")
        } else {
            self._cachedDomain = String(url.prefix(50))
        }
    }
    
    var ageDescription: String {
        let seconds = Date().timeIntervalSince(openedAt)
        if seconds >= 86400 {
            return "\(Int(seconds / 86400))d ago"
        } else if seconds >= 3600 {
            return "\(Int(seconds / 3600))h ago"
        } else if seconds >= 60 {
            return "\(Int(seconds / 60))m ago"
        } else {
            return "\(Int(seconds))s ago"
        }
    }
    
    var ageColor: String {
        let seconds = Date().timeIntervalSince(openedAt)
        if seconds >= 86400 { return "red" }
        if seconds >= 3600 { return "yellow" }
        return "green"
    }
    
    var domain: String {
        _cachedDomain
    }
    
    static func == (lhs: TabInfo, rhs: TabInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TabInfo {
    var isPruningCandidate: Bool {
        let age = Date().timeIntervalSince(openedAt)
        return age > 14400 && !isHighValueDomain
    }
    
    var isHighValueDomain: Bool {
        let highValue = ["github.com", "google.com", "stackoverflow.com", "linear.app", "figma.com"]
        return highValue.contains { domain.contains($0) }
    }
}
