import Foundation

enum ChromeError: Error {
    case notRunning
    case appleScriptFailed(String)
    case timeout
    case ambiguousMatch(String)
}

// MARK: - AppleScript String Escaping

/// Escape a string for safe use in AppleScript
/// Handles quotes, backslashes, and control characters
func appleScriptEscape(_ string: String) -> String {
    // Replace backslash first (so we don't double-escape escaped chars)
    var result = string.replacingOccurrences(of: "\\", with: "\\\\")
    // Replace quotes
    result = result.replacingOccurrences(of: "\"", with: "\\\"")
    // Replace other control characters that could break AppleScript
    result = result.replacingOccurrences(of: "\r", with: "\\r")
    result = result.replacingOccurrences(of: "\n", with: "\\n")
    result = result.replacingOccurrences(of: "\t", with: "\\t")
    return result
}

actor ChromeController {
    static let shared = ChromeController()
    
    private init() {}
    
    func isChromeRunning() async -> Bool {
        let script = """
        tell application "System Events"
            return (name of processes) contains "Google Chrome"
        end tell
        """
        
        do {
            let result = try await runAppleScript(script, timeout: 5)
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            SecureLogger.error("isChromeRunning failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func getWindowCount() async throws -> Int {
        let script = """
        tell application "Google Chrome"
            return count of windows
        end tell
        """
        
        let config = RetryConfig(maxAttempts: 3, baseDelay: 0.5, maxDelay: 3.0)
        
        let result = try await AsyncRetryHandler.retry(config: config) {
            try await self.runAppleScript(script, timeout: 10)
        }
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
    
    /// Ultra-fast single-call scan for all windows and tabs
    /// Returns all tabs from all Chrome windows in one AppleScript execution
    func scanAllTabsFast(progress: @escaping @Sendable (Int, String) -> Void) async throws -> (tabs: [TabInfo], telemetry: ScanTelemetry) {
        guard await isChromeRunning() else {
            throw ChromeError.notRunning
        }
        
        let startTime = Date()
        progress(10, "Scanning all tabs...")
        
        // Get window count first for telemetry
        let windowCount = try await getWindowCount()
        
        // Single AppleScript call to get everything
        let bulkScript = """
        tell application "Google Chrome"
            set allData to ""
            set winIndex to 1
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    set tabData to (winIndex as string) & "|" & (tabIndex as string) & "|" & (URL of t) & "|" & (title of t) & ";"
                    set allData to allData & tabData
                    set tabIndex to tabIndex + 1
                end repeat
                set winIndex to winIndex + 1
            end repeat
            return allData
        end tell
        """
        
        var errors: [String] = []
        var tabs: [TabInfo] = []
        
        do {
            let result = try await runAppleScript(bulkScript, timeout: 60)
            progress(90, "Parsing results...")
            
            let entries = result.components(separatedBy: ";")
            
            for entry in entries {
                let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                // Split on first 3 pipes only — title may contain pipe characters
                let parts = trimmed.components(separatedBy: "|")
                guard parts.count >= 4,
                      let windowId = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let tabIndex = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    continue
                }
                
                let url = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                // Reassemble any remaining parts as the title (handles pipes in title)
                let title = parts[3...].joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)
                
                let tab = TabInfo(
                    id: "w\(windowId)-t\(tabIndex)",
                    windowId: windowId,
                    tabIndex: tabIndex,
                    title: title.isEmpty ? "Untitled" : title,
                    url: url,
                    openedAt: Date()
                )
                tabs.append(tab)
            }
        } catch {
            errors.append(error.localizedDescription)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let uniqueWindows = Set(tabs.map { $0.windowId }).count
        let windowsFailed = windowCount - uniqueWindows
        
        let telemetry = ScanTelemetry(
            windowsAttempted: windowCount,
            windowsFailed: windowsFailed,
            tabsFound: tabs.count,
            errors: errors,
            durationSeconds: duration
        )
        
        progress(100, "Found \(tabs.count) tabs in \(uniqueWindows) windows!")
        return (tabs.sorted { ($0.windowId, $0.tabIndex) < ($1.windowId, $1.tabIndex) }, telemetry)
    }
    
    // scanWindow() was the per-window fallback used before scanAllTabsFast().
    // Retained only for reference; callers should use scanAllTabsFast().
    @available(*, deprecated, renamed: "scanAllTabsFast")
    private func scanWindow(windowId: Int) async throws -> [TabInfo] {
        // Bulk fetch all tabs in window with one AppleScript call
        let bulkScript = """
        tell application "Google Chrome"
            set tabList to tabs of window \(windowId)
            set resultList to {}
            set tabIndex to 1
            repeat with t in tabList
                set tabData to (tabIndex as string) & "|" & (URL of t) & "|" & (title of t)
                set end of resultList to tabData
                set tabIndex to tabIndex + 1
            end repeat
            return resultList as string
        end tell
        """
        
        let result = try await runAppleScript(bulkScript, timeout: 30)
        let tabStrings = result.components(separatedBy: ", ")
        
        var tabs: [TabInfo] = []
        var failedCount = 0
        
        for tabString in tabStrings {
            let parts = tabString.components(separatedBy: "|")
            guard parts.count >= 3,
                  let tabIndex = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                failedCount += 1
                continue
            }
            
            let url = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            
            let tab = TabInfo(
                id: "w\(windowId)-t\(tabIndex)",
                windowId: windowId,
                tabIndex: tabIndex,
                title: title.isEmpty ? "Untitled" : title,
                url: url,
                openedAt: Date()
            )
            tabs.append(tab)
        }
        
        return tabs
    }
    
    func closeTab(windowId: Int, tabIndex: Int) async throws {
        let script = """
        tell application "Google Chrome"
            close tab \(tabIndex) of window \(windowId)
        end tell
        """
        
        _ = try await runAppleScript(script, timeout: 10)
    }
    
    /// Open a new tab with URL in specified window
    func openTab(windowId: Int, url: String) async -> Bool {
        let escapedUrl = appleScriptEscape(url)
        let script = """
        tell application "Google Chrome"
            tell window \(windowId)
                set newTab to make new tab
                set URL of newTab to "\(escapedUrl)"
            end tell
            return "opened"
        end tell
        """
        
        do {
            let result = try await runAppleScript(script, timeout: 10)
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "opened"
        } catch {
            SecureLogger.error("openTab failed for window \(windowId), url: \(url): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get current tab indices for a window (for deterministic close)
    func getWindowTabIndices(windowId: Int) async -> [(index: Int, url: String, title: String)] {
        let script = """
        tell application "Google Chrome"
            set tabList to tabs of window \(windowId)
            set resultList to {}
            set idx to 1
            repeat with t in tabList
                set tabInfo to (idx as string) & "|" & (URL of t) & "|" & (title of t)
                set end of resultList to tabInfo
                set idx to idx + 1
            end repeat
            return resultList as string
        end tell
        """
        
        let config = RetryConfig(maxAttempts: 3, baseDelay: 0.5, maxDelay: 3.0)
        
        do {
            let result = try await AsyncRetryHandler.retry(config: config) {
                try await self.runAppleScript(script, timeout: 10)
            }
            let lines = result.components(separatedBy: ", ")
            var indices: [(Int, String, String)] = []
            
            for line in lines {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 3,
                   let idx = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) {
                    indices.append((idx, parts[1], parts[2]))
                }
            }
            return indices
        } catch {
            SecureLogger.error("getWindowTabIndices failed for window \(windowId): \(error.localizedDescription)")
            return []
        }
    }
    
    /// Legacy close by URL + title (kept for single-tab operations)
    func closeTabByURL(windowId: Int, url: String, title: String? = nil) async -> Bool {
        let escapedUrl = appleScriptEscape(url)
        let escapedTitle = title.map(appleScriptEscape)
        
        let script: String
        if let title = escapedTitle {
            script = """
            tell application "Google Chrome"
                set targetUrl to "\(escapedUrl)"
                set targetTitle to "\(title)"
                set tabList to tabs of window \(windowId)
                repeat with t in tabList
                    if URL of t is targetUrl and title of t is targetTitle then
                        close t
                        return "closed"
                    end if
                end repeat
                return "notfound"
            end tell
            """
        } else {
            script = """
            tell application "Google Chrome"
                set targetUrl to "\(escapedUrl)"
                set tabList to tabs of window \(windowId)
                repeat with t in tabList
                    if URL of t is targetUrl then
                        close t
                        return "closed"
                    end if
                end repeat
                return "notfound"
            end tell
            """
        }
        
        do {
            let result = try await runAppleScript(script, timeout: 10)
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "closed"
        } catch {
            SecureLogger.error("closeTabByURL failed for window \(windowId), url: \(url): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Close tabs deterministically by pre-resolving indices
    /// Closes in descending index order to avoid index shifting issues
    func closeTabsDeterministic(windowId: Int, targets: [(url: String, title: String)]) async -> (closed: Int, failed: Int, ambiguous: Int) {
        // Get current window state
        let currentTabs = await getWindowTabIndices(windowId: windowId)
        
        var toCloseIndices: [Int] = []
        var ambiguous = 0
        
        for target in targets {
            // Find exact matches
            let matches = currentTabs.enumerated().filter { _, tab in
                tab.url == target.url && tab.title == target.title
            }
            
            if matches.count == 1 {
                toCloseIndices.append(matches[0].element.index)
            } else if matches.count > 1 {
                // Ambiguous - skip and count
                ambiguous += 1
            }
            // If no match, tab already closed - skip
        }
        
        // Close in descending index order (highest first to avoid shifting)
        let sortedIndices = toCloseIndices.sorted(by: >)
        var closed = 0
        var failed = 0
        
        for index in sortedIndices {
            let script = """
            tell application "Google Chrome"
                close tab \(index) of window \(windowId)
                return "closed"
            end tell
            """
            
            do {
                let result = try await runAppleScript(script, timeout: 5)
                if result.trimmingCharacters(in: .whitespacesAndNewlines) == "closed" {
                    closed += 1
                } else {
                    failed += 1
                    SecureLogger.warning("closeTabsDeterministic: unexpected result at index \(index)")
                }
            } catch {
                failed += 1
                SecureLogger.error("closeTabsDeterministic failed at index \(index): \(error.localizedDescription)")
            }
        }
        
        return (closed, failed, ambiguous)
    }
    
    func activateTab(windowId: Int, tabIndex: Int) async throws {
        let script = """
        tell application "Google Chrome"
            set active tab index of window \(windowId) to \(tabIndex)
            activate
        end tell
        """
        
        _ = try await runAppleScript(script, timeout: 10)
    }
    
    /// Find current tab index by URL in a specific window
    /// Uses title disambiguation when multiple tabs have same URL
    /// Returns nil if tab no longer exists or if ambiguous without title
    func findTabIndex(windowId: Int, url: String, title: String? = nil) async -> Int? {
        let escapedUrl = appleScriptEscape(url)
        let escapedTitle = title.map(appleScriptEscape)
        
        let script: String
        if let title = escapedTitle {
            // Try URL + title match first, fallback to URL only
            script = """
            tell application "Google Chrome"
                set targetUrl to "\(escapedUrl)"
                set targetTitle to "\(title)"
                set tabList to tabs of window \(windowId)
                set tabIndex to 1
                repeat with t in tabList
                    if URL of t is targetUrl and title of t is targetTitle then
                        return tabIndex
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
                -- Fallback: URL only
                set tabIndex to 1
                repeat with t in tabList
                    if URL of t is targetUrl then
                        return tabIndex
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
                return -1
            end tell
            """
        } else {
            // URL only match
            script = """
            tell application "Google Chrome"
                set targetUrl to "\(escapedUrl)"
                set tabList to tabs of window \(windowId)
                set tabIndex to 1
                repeat with t in tabList
                    if URL of t is targetUrl then
                        return tabIndex
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
                return -1
            end tell
            """
        }
        
        do {
            let result = try await runAppleScript(script, timeout: 10)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = Int(trimmed), index > 0 {
                return index
            }
            return nil
        } catch {
            SecureLogger.error("findTabIndex failed for window \(windowId), url: \(url): \(error.localizedDescription)")
            return nil
        }
    }
    
    func getInstances(knownTabCount: Int = 0) async -> [ChromeInstance] {
        var instances: [ChromeInstance] = []
        
        let isRunning = await isChromeRunning()
        if isRunning {
            do {
                let windowCount = try await getWindowCount()
                instances.append(ChromeInstance(
                    name: "Google Chrome",
                    isRunning: true,
                    windowCount: windowCount,
                    totalTabs: knownTabCount
                ))
            } catch {
                SecureLogger.warning("getInstances: getWindowCount failed: \(error.localizedDescription)")
                instances.append(ChromeInstance(
                    name: "Google Chrome",
                    isRunning: true,
                    windowCount: 0,
                    totalTabs: knownTabCount
                ))
            }
        }
        
        return instances
    }
    
    private func runAppleScript(_ script: String, timeout: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                task.arguments = ["-e", script]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                // Actor-protected flag to prevent double-resume
                actor CompletionFlag {
                    private var completed = false
                    func setCompleted() -> Bool {
                        if completed { return true }
                        completed = true
                        return false
                    }
                }
                let flag = CompletionFlag()
                
                do {
                    try task.run()
                    
                    let timeoutTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        let alreadyCompleted = await flag.setCompleted()
                        if !alreadyCompleted {
                            task.terminate()
                            continuation.resume(throwing: ChromeError.timeout)
                        }
                    }
                    
                    task.waitUntilExit()
                    
                    let alreadyCompleted = await flag.setCompleted()
                    if !alreadyCompleted {
                        timeoutTask.cancel()
                        
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        
                        if task.terminationStatus == 0 {
                            continuation.resume(returning: output)
                        } else {
                            let error = output.trimmingCharacters(in: .whitespacesAndNewlines)
                            if error.contains("Application isn't running") {
                                continuation.resume(throwing: ChromeError.notRunning)
                            } else {
                                continuation.resume(throwing: ChromeError.appleScriptFailed(error))
                            }
                        }
                    }
                } catch {
                    let alreadyCompleted = await flag.setCompleted()
                    if !alreadyCompleted {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - URL Normalization

/// Normalized URL components for duplicate detection
struct NormalizedURL: Hashable {
    let scheme: String
    let host: String
    let path: String
    let query: String? // Sorted, filtered query string
    
    var stringValue: String {
        var result = "\(scheme)://\(host)\(path)"
        if let query = query, !query.isEmpty {
            result += "?\(query)"
        }
        return result
    }
}

/// Normalize URL for duplicate comparison using URLComponents
/// - Removes fragments (#)
/// - Removes tracking query params (utm_, fbclid, etc.) when filterTracking is true
/// - Normalizes host (lowercase, no www)
/// - Preserves path semantics
/// - Sorts remaining query parameters for consistency
func normalizeURL(_ urlString: String, stripQuery: Bool = false, filterTracking: Bool = true) -> String {
    guard let url = URL(string: urlString),
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        // Fallback: simple string normalization
        return urlString.lowercased()
    }
    
    // Normalize scheme and host
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    
    // Remove www. prefix from host
    if let host = components.host, host.hasPrefix("www.") {
        components.host = String(host.dropFirst(4))
    }
    
    // Remove fragment
    components.fragment = nil
    
    // Handle query parameters
    if stripQuery {
        components.query = nil
    } else if filterTracking {
        components.queryItems = filterTrackingParams(from: components.queryItems)
    } else {
        // Sort params for consistent ordering even when tracking params are kept
        if let items = components.queryItems {
            components.queryItems = items.sorted { $0.name < $1.name }
        }
    }
    
    // Normalize path (ensure consistent trailing slash handling)
    // Preserve case for path and query values
    let path = components.path
    if path.hasSuffix("/") && path.count > 1 {
        components.path = String(path.dropLast())
    }
    
    // Return with host lowercased, but path/query preserving original case
    return components.string ?? urlString
}

/// Tracking parameters to remove from URLs
private let trackingParams: Set<String> = [
    // Google Analytics
    "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
    // Facebook
    "fbclid",
    // Google Ads
    "gclid", "gclsrc",
    // TikTok
    "ttclid",
    // Microsoft
    "msclkid",
    // Other common tracking
    "wickedid", "yclid", "dclid",
    "ref", "referrer", "source", "campaign", "medium",
    "cid", "sid", "sessionid",
    "affiliate", "aff_id", "partner", "subid"
]

/// Filter tracking parameters from query items
private func filterTrackingParams(from items: [URLQueryItem]?) -> [URLQueryItem]? {
    guard let items = items else { return nil }
    
    let filtered = items.filter { item in
        let name = item.name.lowercased()
        return !trackingParams.contains(name)
    }
    
    // Sort for consistent ordering
    return filtered.sorted { $0.name < $1.name }
}

// MARK: - String Extension

extension String {
    /// Normalize URL for duplicate comparison (backwards compatible)
    func normalizedForComparison() -> String {
        normalizeURL(self)
    }
}
