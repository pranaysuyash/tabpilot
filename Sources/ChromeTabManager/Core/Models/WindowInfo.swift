import Foundation

struct WindowInfo: Identifiable, Sendable {
    var id: Int { windowId }
    let windowId: Int
    let tabCount: Int
    var tabs: [TabInfo]
    var activeTabIndex: Int
    var profileName: String

    init(windowId: Int, tabCount: Int, tabs: [TabInfo], activeTabIndex: Int, profileName: String = "Default") {
        self.windowId = windowId
        self.tabCount = tabCount
        self.tabs = tabs
        self.activeTabIndex = activeTabIndex
        self.profileName = profileName
    }
}
