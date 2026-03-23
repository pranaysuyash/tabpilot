import XCTest
@testable import ChromeTabManager

final class ChromeTabManagerTests: XCTestCase {
    
    // MARK: - URL Normalization Tests
    
    func testNormalizeURLRemovesTrackingParams() {
        let url = "https://example.com/page?utm_source=google&fbclid=xyz&id=123"
        let normalized = normalizeURL(url)
        
        XCTAssertTrue(normalized.contains("example.com"))
        XCTAssertTrue(normalized.contains("/page"))
        XCTAssertTrue(normalized.contains("id=123"))
        XCTAssertFalse(normalized.contains("utm_source"))
        XCTAssertFalse(normalized.contains("fbclid"))
    }
    
    func testNormalizeURLPreservesCaseSensitivePath() {
        let url = "https://example.com/Path/To/Page"
        let normalized = normalizeURL(url)
        
        // Host should be lowercase
        XCTAssertTrue(normalized.contains("example.com"))
        // Path case should be preserved
        XCTAssertTrue(normalized.contains("/Path/To/Page"))
    }
    
    func testNormalizeURLRemovesFragment() {
        let url = "https://example.com/page#section"
        let normalized = normalizeURL(url)
        
        XCTAssertFalse(normalized.contains("#section"))
        XCTAssertTrue(normalized.contains("/page"))
    }
    
    func testNormalizeURLRemovesWWW() {
        let url = "https://www.example.com/page"
        let normalized = normalizeURL(url)
        
        XCTAssertFalse(normalized.contains("www."))
        XCTAssertTrue(normalized.contains("example.com"))
    }
    
    // MARK: - String Extension Tests
    
    func testAppleScriptEscape() {
        let input = "Hello \"World\" \\ Test"
        let escaped = appleScriptEscape(input)
        
        // Should escape quotes and backslashes
        XCTAssertTrue(escaped.contains("\\\""))
        XCTAssertTrue(escaped.contains("\\\\"))
    }
    
    func testNormalizedForComparison() {
        // Test that URLs with tracking params normalize to same base
        let url1 = "https://example.com/page?utm_source=test"
        let url2 = "https://example.com/page?utm_medium=email"
        
        // Both should have tracking params removed, resulting in same normalized URL
        let normalized1 = url1.normalizedForComparison()
        let normalized2 = url2.normalizedForComparison()
        
        XCTAssertEqual(normalized1, normalized2)
        XCTAssertTrue(normalized1.contains("example.com/page"))
        XCTAssertFalse(normalized1.contains("utm_"))
    }
    
    // MARK: - View Mode Tests
    
    func testViewModeDescriptions() {
        XCTAssertEqual(TabManagerViewModel.DuplicateViewMode.overall.description, "Show all duplicates grouped by URL")
        XCTAssertEqual(TabManagerViewModel.DuplicateViewMode.byWindow.description, "Group duplicates by which window they are in")
        XCTAssertEqual(TabManagerViewModel.DuplicateViewMode.byDomain.description, "Group duplicates by website domain")
        XCTAssertEqual(TabManagerViewModel.DuplicateViewMode.crossWindow.description, "Show only duplicates that exist in multiple windows")
    }
    
    func testViewModeIcons() {
        XCTAssertEqual(TabManagerViewModel.DuplicateViewMode.overall.icon, "doc.on.doc")
        XCTAssertEqual(TabManagerViewModel.DuplicateViewMode.byWindow.icon, "uiwindow.split.2x1")
    }
    
    // MARK: - Persona Detection Tests
    
    func testLightPersona() {
        let analysis = analyzeUser(tabs: [], duplicates: [])
        XCTAssertEqual(analysis.persona, .light)
    }
    
    func testStandardPersona() {
        // Create 60 tabs across 6 windows
        let tabs = (1...60).map { i in
            TabInfo(id: "t\(i)", windowId: (i / 10) + 1, tabIndex: i, title: "Tab", url: "https://example.com/\(i)", openedAt: Date())
        }
        let analysis = analyzeUser(tabs: tabs, duplicates: [])
        XCTAssertEqual(analysis.persona, .standard)
    }
    
    func testSuperUserPersona() {
        // Create 1100 tabs across 60 windows
        let tabs = (1...1100).map { i in
            TabInfo(id: "t\(i)", windowId: (i / 20) + 1, tabIndex: i, title: "Tab", url: "https://example.com/\(i)", openedAt: Date())
        }
        let analysis = analyzeUser(tabs: tabs, duplicates: [])
        XCTAssertEqual(analysis.persona, .superUser)
    }
    
    // MARK: - Protected Domain Tests
    
    func testProtectedDomainMatching() {
        let protected = ["mail.google.com", "calendar.google.com"]
        
        // Test exact match
        XCTAssertTrue(isDomainProtected(url: "https://mail.google.com/inbox", protected: protected))
        // Test subdomain match
        XCTAssertTrue(isDomainProtected(url: "https://calendar.google.com/calendar", protected: protected))
        // Test non-protected
        XCTAssertFalse(isDomainProtected(url: "https://drive.google.com", protected: protected))
    }
    
    func testProtectedDomainSubdomainMatching() {
        let protected = ["google.com"]
        
        // Subdomain should match parent
        XCTAssertTrue(isDomainProtected(url: "https://mail.google.com", protected: protected))
        // Parent should match subdomain
        XCTAssertTrue(isDomainProtected(url: "https://docs.google.com", protected: protected))
    }
    
    // MARK: - Duplicate Group Tests
    
    func testDuplicateGroupWastedCount() {
        let tabs = [
            TabInfo(id: "t1", windowId: 1, tabIndex: 1, title: "Test", url: "https://example.com", openedAt: Date()),
            TabInfo(id: "t2", windowId: 1, tabIndex: 2, title: "Test", url: "https://example.com", openedAt: Date()),
            TabInfo(id: "t3", windowId: 1, tabIndex: 3, title: "Test", url: "https://example.com", openedAt: Date())
        ]
        
        let group = DuplicateGroup(normalizedUrl: "https://example.com", displayUrl: "https://example.com", tabs: tabs)
        
        XCTAssertEqual(group.wastedCount, 2)
    }
    
    func testDuplicateGroupOldestNewest() {
        let oldDate = Date().addingTimeInterval(-3600)
        let newDate = Date()
        
        let tabs = [
            TabInfo(id: "t1", windowId: 1, tabIndex: 1, title: "Test", url: "https://example.com", openedAt: newDate),
            TabInfo(id: "t2", windowId: 1, tabIndex: 2, title: "Test", url: "https://example.com", openedAt: oldDate),
            TabInfo(id: "t3", windowId: 1, tabIndex: 3, title: "Test", url: "https://example.com", openedAt: Date())
        ]
        
        let group = DuplicateGroup(normalizedUrl: "https://example.com", displayUrl: "https://example.com", tabs: tabs)
        
        XCTAssertEqual(group.oldestTab?.id, "t2")
        XCTAssertEqual(group.newestTab?.id, "t3")
    }
}

// MARK: - Helper Functions for Testing

private func isDomainProtected(url: String, protected: [String]) -> Bool {
    guard let host = URL(string: url)?.host?.lowercased() else { return false }
    return protected.contains { host.contains($0) || $0.contains(host) }
}

private func normalizeURLForTest(_ urlString: String) -> String {
    guard let url = URL(string: urlString),
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return urlString.lowercased()
    }
    
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    
    if let host = components.host, host.hasPrefix("www.") {
        components.host = String(host.dropFirst(4))
    }
    
    components.fragment = nil
    
    return components.string ?? urlString
}
