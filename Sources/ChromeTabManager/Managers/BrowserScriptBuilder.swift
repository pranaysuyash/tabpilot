import Foundation

enum BrowserScriptBuilder {
    static func isRunningScript(browserName: String) -> String {
        """
        tell application "System Events"
            set browserApp to application process "\(browserName)"
            return exists browserApp
        end tell
        """
    }

    static func windowCountScript(browserName: String) -> String {
        """
        tell application "\(browserName)"
            return count of windows
        end tell
        """
    }

    static func scanTabsScript(browserName: String) -> String {
        """
        tell application "\(browserName)"
            set tabInfo to ""
            set winIndex to 1
            repeat with theWindow in windows
                set tabIndex to 1
                repeat with theTab in tabs of theWindow
                    set tabURL to URL of theTab
                    set tabTitle to title of theTab
                    set tabInfo to tabInfo & winIndex & "|" & tabIndex & "|" & tabURL & "|" & tabTitle & ";"
                    set tabIndex to tabIndex + 1
                end repeat
                set winIndex to winIndex + 1
            end repeat
            return tabInfo
        end tell
        """
    }

    static func closeTabScript(browserName: String, windowId: Int, tabIndex: Int) -> String {
        """
        tell application "\(browserName)"
            tell window \(windowId)
                close tab \(tabIndex)
            end tell
        end tell
        """
    }

    static func activateTabScript(browserName: String, windowId: Int, tabIndex: Int) -> String {
        """
        tell application "\(browserName)"
            tell window \(windowId)
                set active tab to tab \(tabIndex)
            end tell
            activate
        end tell
        """
    }

    static func openTabScript(browserName: String, windowId: Int, url: String) -> String {
        let escapedURL = url.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "\(browserName)"
            tell window \(windowId)
                open location "\(escapedURL)"
            end tell
        end tell
        """
    }
}
