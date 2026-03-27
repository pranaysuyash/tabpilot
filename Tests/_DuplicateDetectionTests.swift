import XCTest
@testable import ChromeTabManager

final class DuplicateDetectionTests: XCTestCase {
    
    // MARK: - URL Normalization for Duplicates
    
    func testTrackingParamsFilteredForDuplicateDetection() {
        let url1 = "https://example.com/page?utm_source=google&fbclid=abc"
        let url2 = "https://example.com/page?fbclid=xyz&utm_source=bing"
        let url3 = "https://example.com/page"
        
        let n1 = normalizeURL(url1, stripQuery: false, filterTracking: true)
        let n2 = normalizeURL(url2, stripQuery: false, filterTracking: true)
        let n3 = normalizeURL(url3, stripQuery: false, filterTracking: true)
        
        XCTAssertEqual(n1, n2, "URLs differing only in tracking params should be duplicates")
        XCTAssertEqual(n1, n3, "URL with tracking params should match clean URL")
    }
    
    func testDifferentPathsNotDuplicates() {
        let url1 = "https://example.com/page-a"
        let url2 = "https://example.com/page-b"
        
        let n1 = normalizeURL(url1, stripQuery: false, filterTracking: true)
        let n2 = normalizeURL(url2, stripQuery: false, filterTracking: true)
        
        XCTAssertNotEqual(n1, n2, "Different paths should not be duplicates")
    }
    
    func testWWWStrippedForDuplicateDetection() {
        let url1 = "https://www.example.com/page"
        let url2 = "https://example.com/page"
        
        let n1 = normalizeURL(url1, stripQuery: false, filterTracking: true)
        let n2 = normalizeURL(url2, stripQuery: false, filterTracking: true)
        
        XCTAssertEqual(n1, n2, "www prefix should be stripped for duplicate detection")
    }
    
    func testCaseInsensitiveHostDuplicateDetection() {
        let url1 = "https://EXAMPLE.COM/page"
        let url2 = "https://example.com/page"
        
        let n1 = normalizeURL(url1, stripQuery: false, filterTracking: true)
        let n2 = normalizeURL(url2, stripQuery: false, filterTracking: true)
        
        XCTAssertEqual(n1, n2, "Host should be case-insensitive for duplicate detection")
    }
    
    // MARK: - Duplicate Grouping Logic
    
    func testDuplicateGroupWastedCount() {
        let now = Date()
        let tabs = [
            TabInfo(id: "1", windowId: 1, tabIndex: 1, title: "Test", url: "https://example.com", openedAt: now),
            TabInfo(id: "2", windowId: 1, tabIndex: 2, title: "Test", url: "https://example.com", openedAt: now),
        ]
        
        let group = DuplicateGroup(normalizedUrl: "https://example.com", displayUrl: "https://example.com", tabs: tabs)
        
        XCTAssertEqual(group.wastedCount, 1, "2 tabs = 1 wasted")
    }
    
    func testDuplicateGroupWithManyTabs() {
        let now = Date()
        var tabs: [TabInfo] = []
        for i in 0..<20 {
            tabs.append(TabInfo(
                id: "\(i)",
                windowId: i / 4 + 1,
                tabIndex: i % 4 + 1,
                title: "Same",
                url: "https://example.com/page",
                openedAt: now.addingTimeInterval(Double(-i * 60))
            ))
        }
        
        let group = DuplicateGroup(normalizedUrl: "https://example.com", displayUrl: "https://example.com", tabs: tabs)
        
        XCTAssertEqual(group.wastedCount, 19, "20 tabs = 19 wasted")
        XCTAssertEqual(group.oldestTab?.id, "19", "Oldest should be tab with earliest timestamp")
        XCTAssertEqual(group.newestTab?.id, "0", "Newest should be tab with latest timestamp")
    }
    
    func testDuplicateGroupTimeSpan() {
        let now = Date()
        let tabs = [
            TabInfo(id: "1", windowId: 1, tabIndex: 1, title: "Test", url: "https://example.com", openedAt: now.addingTimeInterval(-7200)),
            TabInfo(id: "2", windowId: 1, tabIndex: 2, title: "Test", url: "https://example.com", openedAt: now),
        ]
        
        let group = DuplicateGroup(normalizedUrl: "https://example.com", displayUrl: "https://example.com", tabs: tabs)
        
        XCTAssertTrue(group.timeSpan.contains("h"), "Time span should show hours")
    }
    
    // MARK: - Full Duplicate Detection Pipeline
    
    func testDuplicateDetectionPipeline() {
        let now = Date()
        let tabs = [
            // Group 1: example.com/page - 3 tabs
            TabInfo(id: "1", windowId: 1, tabIndex: 1, title: "Page", url: "https://example.com/page", openedAt: now),
            TabInfo(id: "2", windowId: 1, tabIndex: 2, title: "Page", url: "https://example.com/page?fbclid=abc", openedAt: now),
            TabInfo(id: "3", windowId: 2, tabIndex: 1, title: "Page", url: "https://example.com/page", openedAt: now),
            // Group 2: example.com/other - 2 tabs
            TabInfo(id: "4", windowId: 1, tabIndex: 3, title: "Other", url: "https://example.com/other", openedAt: now),
            TabInfo(id: "5", windowId: 3, tabIndex: 1, title: "Other", url: "https://example.com/other", openedAt: now),
            // Unique: other.com
            TabInfo(id: "6", windowId: 4, tabIndex: 1, title: "Unique", url: "https://other.com", openedAt: now),
        ]
        
        // Simulate findDuplicates logic
        let filteredTabs = tabs.filter { tab in
            guard let host = URL(string: tab.url)?.host?.lowercased() else { return true }
            let protectedDomains = UserDefaults.standard.stringArray(forKey: "protectedDomains") ?? ["mail.google.com", "calendar.google.com"]
            return !protectedDomains.contains { host.contains($0) || $0.contains(host) }
        }
        
        let grouped = Dictionary(grouping: filteredTabs) { tab in
            normalizeURL(tab.url, stripQuery: false, filterTracking: true)
        }
        
        let duplicates = grouped.filter { $0.value.count > 1 }
        
        XCTAssertEqual(duplicates.count, 2, "Should find 2 duplicate groups")
        
        let sortedGroups = duplicates.map { url, tabs in
            DuplicateGroup(normalizedUrl: url, displayUrl: tabs.first?.url ?? url, tabs: tabs)
        }.sorted { $0.tabs.count > $1.tabs.count }
        
        XCTAssertEqual(sortedGroups[0].tabs.count, 3, "Largest group should have 3 tabs")
        XCTAssertEqual(sortedGroups[1].tabs.count, 2, "Second group should have 2 tabs")
        XCTAssertEqual(sortedGroups[0].wastedCount, 2, "3 tabs = 2 wasted")
        XCTAssertEqual(sortedGroups[1].wastedCount, 1, "2 tabs = 1 wasted")
    }
    
    func testProtectedDomainsExcludedFromDuplicates() {
        let now = Date()
        let tabs = [
            TabInfo(id: "1", windowId: 1, tabIndex: 1, title: "Gmail", url: "https://mail.google.com/mail", openedAt: now),
            TabInfo(id: "2", windowId: 1, tabIndex: 2, title: "Gmail2", url: "https://mail.google.com/mail?fbclid=xyz", openedAt: now),
            TabInfo(id: "3", windowId: 1, tabIndex: 3, title: "Calendar", url: "https://calendar.google.com/calendar", openedAt: now),
            TabInfo(id: "4", windowId: 1, tabIndex: 4, title: "Calendar2", url: "https://calendar.google.com/calendar?fbclid=abc", openedAt: now),
            TabInfo(id: "5", windowId: 1, tabIndex: 5, title: "Regular", url: "https://example.com/page", openedAt: now),
            TabInfo(id: "6", windowId: 1, tabIndex: 6, title: "Regular2", url: "https://example.com/page", openedAt: now),
        ]
        
        let filteredTabs = tabs.filter { tab in
            guard let host = URL(string: tab.url)?.host?.lowercased() else { return true }
            let protectedDomains = UserDefaults.standard.stringArray(forKey: "protectedDomains") ?? ["mail.google.com", "calendar.google.com"]
            return !protectedDomains.contains { host.contains($0) || $0.contains(host) }
        }
        
        XCTAssertEqual(filteredTabs.count, 2, "Only example.com tabs should remain after filtering")
        
        let grouped = Dictionary(grouping: filteredTabs) { tab in
            normalizeURL(tab.url, stripQuery: false, filterTracking: true)
        }
        let duplicates = grouped.filter { $0.value.count > 1 }
        
        XCTAssertEqual(duplicates.count, 1, "Should find 1 duplicate group for example.com")
    }
    
    // MARK: - URL Edge Cases
    
    func testURLsWithDifferentQueryParamOrder() {
        let url1 = "https://example.com/page?a=1&b=2&c=3"
        let url2 = "https://example.com/page?c=3&b=2&a=1"
        
        let n1 = normalizeURL(url1, stripQuery: false, filterTracking: true)
        let n2 = normalizeURL(url2, stripQuery: false, filterTracking: true)
        
        XCTAssertEqual(n1, n2, "Query params should be sorted for consistent duplicate detection")
    }
    
    func testFragmentsIgnoredForDuplicates() {
        let url1 = "https://example.com/page#section1"
        let url2 = "https://example.com/page#section2"
        
        let n1 = normalizeURL(url1, stripQuery: false, filterTracking: true)
        let n2 = normalizeURL(url2, stripQuery: false, filterTracking: true)
        
        XCTAssertEqual(n1, n2, "Fragments should be ignored for duplicate detection")
    }
    
    // MARK: - Tracking Source Extraction
    
    func testExtractTrackingSourcesFromFacebookURL() {
        let url = "https://example.com/page?utm_source=facebook&fbclid=abc123"
        let sources = extractTrackingSources(from: url)
        
        XCTAssertTrue(sources.contains("Facebook"), "Should detect Facebook tracking")
        XCTAssertTrue(sources.contains("Google Analytics (UTM)"), "Should detect UTM source")
        XCTAssertEqual(sources.count, 2, "Should find 2 tracking sources")
    }
    
    func testExtractTrackingSourcesFromGoogleAdsURL() {
        let url = "https://shop.example.com/product?utm_campaign=spring_sale&gclid=xyz789"
        let sources = extractTrackingSources(from: url)
        
        XCTAssertTrue(sources.contains("Google Ads"), "Should detect Google Ads")
        XCTAssertTrue(sources.contains("Google Analytics (UTM Campaign)"), "Should detect UTM campaign")
    }
    
    func testExtractPrimaryTrackingSource() {
        // utm_source appears first in URL, so it wins
        let facebookURL = "https://example.com/page?utm_source=facebook&fbclid=abc"
        // fbclid appears first, so it wins
        let fbclidFirstURL = "https://example.com/page?fbclid=abc&utm_source=facebook"
        let googleAdsURL = "https://example.com/product?gclid=xyz"
        let noTrackingURL = "https://example.com/page"
        
        // First param in URL order that matches priority list wins
        XCTAssertEqual(extractPrimaryTrackingSource(from: facebookURL), "Google Analytics (UTM)")
        XCTAssertEqual(extractPrimaryTrackingSource(from: fbclidFirstURL), "Facebook")
        XCTAssertEqual(extractPrimaryTrackingSource(from: googleAdsURL), "Google Ads")
        XCTAssertNil(extractPrimaryTrackingSource(from: noTrackingURL))
    }
    
    func testExtractMultipleTrackingSourcesFromSameURL() {
        let url = "https://shop.example.com/checkout?utm_source=newsletter&utm_medium=email&fbclid=abc&gclid=xyz"
        let sources = extractTrackingSources(from: url)
        
        XCTAssertTrue(sources.contains("Facebook"), "Should detect Facebook")
        XCTAssertTrue(sources.contains("Google Ads"), "Should detect Google Ads")
        XCTAssertTrue(sources.contains("Google Analytics (UTM)"), "Should detect UTM source")
        XCTAssertTrue(sources.contains("Google Analytics (UTM Medium)"), "Should detect UTM medium")
        XCTAssertEqual(sources.count, 4, "Should find 4 tracking sources")
    }
    
    func testNoTrackingSourcesInCleanURL() {
        let url = "https://example.com/product?id=123&category=electronics"
        let sources = extractTrackingSources(from: url)
        
        XCTAssertTrue(sources.isEmpty, "Clean URL with no tracking params should return empty array")
    }
    
    func testExtractTrackingSourcesFromTikTokURL() {
        let url = "https://example.com/video?utm_source=tiktok&ttclid=abc123"
        let sources = extractTrackingSources(from: url)
        
        XCTAssertTrue(sources.contains("TikTok Ads"), "Should detect TikTok Ads")
        XCTAssertTrue(sources.contains("Google Analytics (UTM)"), "Should detect UTM source")
    }
}
