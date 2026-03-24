import Foundation

struct WindowInfo: Identifiable, Sendable {
    let id = UUID()
    let windowId: Int
    let tabCount: Int
    var tabs: [TabInfo]
    var activeTabIndex: Int
}
