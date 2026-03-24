import Foundation

struct WindowInfo: Identifiable, Sendable {
    var id: Int { windowId }
    let windowId: Int
    let tabCount: Int
    var tabs: [TabInfo]
    var activeTabIndex: Int
}
