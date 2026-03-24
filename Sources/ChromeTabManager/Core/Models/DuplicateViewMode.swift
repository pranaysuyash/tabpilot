import Foundation

enum DuplicateViewMode: String, CaseIterable, Sendable {
    case overall = "Overall"
    case byWindow = "By Window"
    case byDomain = "By Domain"
    case crossWindow = "Cross-Window"
    
    var icon: String {
        switch self {
        case .overall: return "doc.on.doc"
        case .byWindow: return "uiwindow.split.2x1"
        case .byDomain: return "globe"
        case .crossWindow: return "arrow.left.arrow.right"
        }
    }
    
    var description: String {
        switch self {
        case .overall: return "Show all duplicates grouped by URL"
        case .byWindow: return "Group duplicates by which window they are in"
        case .byDomain: return "Group duplicates by website domain"
        case .crossWindow: return "Show only duplicates that exist in multiple windows"
        }
    }
}
