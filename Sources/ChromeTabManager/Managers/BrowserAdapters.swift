import Foundation
import AppKit

protocol BrowserController: Sendable {
    var browserName: String { get }
    var isRunning: Bool { get async }
    
    func getWindowCount() async throws -> Int
    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> [TabInfo]
    func closeTab(windowId: Int, tabIndex: Int) async throws
    func activateTab(windowId: Int, tabIndex: Int) async throws
    func openTab(windowId: Int, url: String) async -> Bool
}

extension BrowserController {
    func scanAllTabsFast(progress: @escaping @Sendable (Int, String) -> Void) async throws -> (tabs: [TabInfo], telemetry: ScanTelemetry) {
        let startTime = Date()
        let tabs = try await scanAllTabs { p, m in progress(p, m) }
        let duration = Date().timeIntervalSince(startTime)
        let uniqueWindows = Set(tabs.map { $0.windowId }).count
        let telemetry = ScanTelemetry(
            windowsAttempted: 0,
            windowsFailed: 0,
            tabsFound: tabs.count,
            errors: [],
            durationSeconds: duration
        )
        return (tabs, telemetry)
    }
}

enum Browser: String, CaseIterable, Sendable {
    case chrome = "Google Chrome"
    case arc = "Arc"
    case edge = "Microsoft Edge"
    case brave = "Brave Browser"
    case vivaldi = "Vivaldi"
    
    var id: String { rawValue }
    
    var controller: BrowserController {
        switch self {
        case .chrome: return ChromeBrowserAdapter()
        case .arc: return ArcBrowserAdapter()
        case .edge: return EdgeBrowserAdapter()
        case .brave: return BraveBrowserAdapter()
        case .vivaldi: return VivaldiBrowserAdapter()
        }
    }
    
    var isAvailable: Bool {
        let runningApps = NSWorkspace.shared.runningApplications.map { $0.localizedName ?? "" }
        return runningApps.contains(rawValue)
    }
}

struct ChromeBrowserAdapter: BrowserController {
    let browserName = "Google Chrome"
    
    var isRunning: Bool {
        get async {
            await ChromeController.shared.isChromeRunning()
        }
    }
    
    func getWindowCount() async throws -> Int {
        try await ChromeController.shared.getWindowCount()
    }
    
    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> [TabInfo] {
        let result = try await ChromeController.shared.scanAllTabsFast(progress: progress)
        return result.tabs
    }
    
    func closeTab(windowId: Int, tabIndex: Int) async throws {
        try await ChromeController.shared.closeTab(windowId: windowId, tabIndex: tabIndex)
    }
    
    func activateTab(windowId: Int, tabIndex: Int) async throws {
        try await ChromeController.shared.activateTab(windowId: windowId, tabIndex: tabIndex)
    }
    
    func openTab(windowId: Int, url: String) async -> Bool {
        await ChromeController.shared.openTab(windowId: windowId, url: url)
    }
}

class BaseBrowserAdapter: BrowserController {
    let browserName: String
    
    init(browserName: String) {
        self.browserName = browserName
    }
    
    var isRunning: Bool {
        get async {
            let script = BrowserScriptBuilder.isRunningScript(browserName: browserName)
            do {
                let result = try await ChromeController.shared.runAppleScript(script, timeout: 5)
                return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            } catch {
                return false
            }
        }
    }
    
    func getWindowCount() async throws -> Int {
        let script = BrowserScriptBuilder.windowCountScript(browserName: browserName)
        let result = try await ChromeController.shared.runAppleScript(script, timeout: 10)
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
    
    func scanAllTabs(progress: @escaping @Sendable (Int, String) -> Void) async throws -> [TabInfo] {
        progress(10, "Scanning \(browserName) tabs...")
        let script = BrowserScriptBuilder.scanTabsScript(browserName: browserName)
        
        progress(50, "Fetching \(browserName) data...")
        let result = try await ChromeController.shared.runAppleScript(script, timeout: 60)
        progress(90, "Parsing results...")
        
        var tabs: [TabInfo] = []
        let entries = result.components(separatedBy: ";")
        let lowercaseBrowserName = browserName.lowercased()
        
        for entry in entries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            var parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 4,
                  let windowId = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let tabIndex = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }
            
            let url = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = parts[3...].joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)
            
            tabs.append(TabInfo(
                id: "\(lowercaseBrowserName)-w\(windowId)-t\(tabIndex)",
                windowId: windowId,
                tabIndex: tabIndex,
                title: title.isEmpty ? "Untitled" : title,
                url: url,
                openedAt: Date()
            ))
        }
        
        progress(100, "Found \(tabs.count) tabs in \(browserName)!")
        return tabs
    }
    
    func closeTab(windowId: Int, tabIndex: Int) async throws {
        let script = BrowserScriptBuilder.closeTabScript(browserName: browserName, windowId: windowId, tabIndex: tabIndex)
        _ = try await ChromeController.shared.runAppleScript(script, timeout: 10)
    }
    
    func activateTab(windowId: Int, tabIndex: Int) async throws {
        let script = BrowserScriptBuilder.activateTabScript(browserName: browserName, windowId: windowId, tabIndex: tabIndex)
        _ = try await ChromeController.shared.runAppleScript(script, timeout: 10)
    }
    
    func openTab(windowId: Int, url: String) async -> Bool {
        let script = BrowserScriptBuilder.openTabScript(browserName: browserName, windowId: windowId, url: url)
        do {
            _ = try await ChromeController.shared.runAppleScript(script, timeout: 10)
            return true
        } catch {
            return false
        }
    }
}

final class ArcBrowserAdapter: BaseBrowserAdapter {
    init() { super.init(browserName: "Arc") }
}

final class EdgeBrowserAdapter: BaseBrowserAdapter {
    init() { super.init(browserName: "Microsoft Edge") }
}

final class BraveBrowserAdapter: BaseBrowserAdapter {
    init() { super.init(browserName: "Brave Browser") }
}

final class VivaldiBrowserAdapter: BaseBrowserAdapter {
    init() { super.init(browserName: "Vivaldi") }
}
