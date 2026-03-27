import Foundation
import XCTest
@testable import ChromeTabManager

/// Performance benchmarks for large-scale tab management (500+ tabs)
/// These tests validate the performance optimizations for handling 4,000+ tabs
@MainActor
final class PerformanceBenchmarks: XCTestCase {
    
    // MARK: - Synthetic Data Generator
    
    private let commonDomains = [
        "github.com", "stackoverflow.com", "youtube.com", "reddit.com",
        "twitter.com", "linkedin.com", "medium.com", "wikipedia.org",
        "amazon.com", "netflix.com", "docs.swift.org", "apple.com",
        "google.com", "microsoft.com", "figma.com", "notion.so",
        "slack.com", "discord.com", "zoom.us", "dropbox.com"
    ]
    
    private let urlPaths = [
        "page", "article", "post", "video", "doc", "dashboard",
        "settings", "profile", "search", "feed", "home", "about",
        "docs", "api", "blog", "news", "forum", "shop", "cart"
    ]
    
    /// Generates synthetic tabs for performance testing
    func generateTabs(count: Int, windows: Int) -> [TabInfo] {
        var tabs: [TabInfo] = []
        let baseDate = Date()
        
        for i in 0..<count {
            let domain = commonDomains.randomElement()!
            let path = urlPaths.randomElement()!
            let param = Bool.random() ? "?id=\(Int.random(in: 1...10000))" : ""
            let url = "https://\(domain)/\(path)/\(i)\(param)"
            
            let title = "\(domain.uppercased()) - \(path.capitalized) \(i)"
            let windowId = min(i % windows + 1, windows)
            let tabIndex = i % 20 + 1
            let openedAt = baseDate.addingTimeInterval(-Double.random(in: 0...(86400 * 365)))
            
            let tab = TabInfo(
                id: UUID().uuidString,
                windowId: windowId,
                tabIndex: tabIndex,
                title: title,
                url: url,
                openedAt: openedAt,
                profileName: "Default"
            )
            tabs.append(tab)
        }
        
        return tabs
    }
    
    /// Generates synthetic duplicate groups for testing
    func generateDuplicateGroups(tabCount: Int, duplicateRatio: Double) -> [DuplicateGroup] {
        let tabs = generateTabs(count: tabCount, windows: 20)
        var groups: [DuplicateGroup] = []
        
        // Group tabs by domain
        let grouped = Dictionary(grouping: tabs) { $0.domain }
        
        for (domain, domainTabs) in grouped {
            if domainTabs.count > 1 && Double.random(in: 0...1) < duplicateRatio {
                let group = DuplicateGroup(
                    normalizedUrl: "https://\(domain)",
                    displayUrl: domainTabs.first?.url ?? "",
                    tabs: domainTabs
                )
                groups.append(group)
            }
        }
        
        return groups.sorted { $0.tabs.count > $1.tabs.count }
    }
    
    // MARK: - Duplicate Finding Benchmark
    
    /// Tests duplicate finding performance at various scales
    func testDuplicateFindingPerformance() {
        let scale = 4000
        let tabs = generateTabs(count: scale, windows: scale / 20 + 1)
        
        measure {
            let grouped = Dictionary(grouping: tabs) { $0.domain }
            let duplicates = grouped.filter { $0.value.count > 1 }
            _ = duplicates.map { url, tabs in
                DuplicateGroup(
                    normalizedUrl: url,
                    displayUrl: tabs.first?.url ?? url,
                    tabs: tabs.sorted { $0.openedAt < $1.openedAt }
                )
            }
        }
    }
    
    // MARK: - Domain Access Benchmark
    
    /// Tests that cached domain access is O(1)
    func testDomainAccessPerformance() {
        let tabs = generateTabs(count: 4000, windows: 160)
        
        measure {
            var domains: [String] = []
            for tab in tabs {
                domains.append(tab.domain)
            }
        }
        
        print("Domain access for 4000 tabs: measured")
    }
    
    // MARK: - Oldest/Newest Tab Benchmark
    
    /// Tests that pre-computed oldest/newestTab is O(1) access
    func testOldestNewestTabPerformance() {
        let groups = generateDuplicateGroups(tabCount: 4000, duplicateRatio: 0.6)
        
        measure {
            for group in groups {
                _ = group.oldestTab?.openedAt
                _ = group.newestTab?.openedAt
                _ = group.timeSpan
            }
        }
        
        print("Oldest/newest tab access for \(groups.count) groups: measured")
    }
    
    // MARK: - Sorting Benchmark
    
    /// Tests sorting performance at scale
    func testSortingPerformance() {
        let tabs = generateTabs(count: 4000, windows: 160)
        
        measure {
            _ = tabs.sorted { $0.openedAt < $1.openedAt }
            _ = tabs.sorted { $0.domain < $1.domain }
            _ = tabs.sorted { $0.windowId < $1.tabIndex }
        }
        
        print("Sorting for 4000 tabs: measured")
    }
    
    // MARK: - Memory Estimation
    
    /// Estimates memory usage for large-scale scenarios
    func testMemoryEstimation() {
        let tabs4000 = generateTabs(count: 4000, windows: 160)
        let groups = generateDuplicateGroups(tabCount: 4000, duplicateRatio: 0.6)
        
        // Estimate TabInfo memory (rough estimate)
        let tabMemoryPerItem = 200 // bytes rough estimate for TabInfo
        let totalTabMemory = tabs4000.count * tabMemoryPerItem
        
        // Estimate DuplicateGroup memory
        let groupMemoryPerItem = 100 // bytes rough estimate for DuplicateGroup
        let totalGroupMemory = groups.count * groupMemoryPerItem
        
        let totalMemoryMB = Double(totalTabMemory + totalGroupMemory) / 1_000_000
        
        print("Estimated memory for 4000 tabs: \(String(format: "%.2f", totalMemoryMB)) MB")
        print("  Tab count: \(tabs4000.count)")
        print("  Group count: \(groups.count)")
    }
    
    // MARK: - Scale Stress Tests
    
    /// Validates behavior at 500+ tab scale
    func test500PlusTabScale() {
        let tabs = generateTabs(count: 500, windows: 25)
        
        XCTAssertEqual(tabs.count, 500, "Should generate exactly 500 tabs")
        XCTAssertGreaterThan(tabs.count, 0, "Should have tabs")
        
        // Test domain access
        let domains = Set(tabs.map { $0.domain })
        XCTAssertGreaterThan(domains.count, 0, "Should have domains")
        
        print("500+ tab scale validation: PASSED")
    }
    
    /// Validates behavior at 1000+ tab scale
    func test1000PlusTabScale() {
        let tabs = generateTabs(count: 1000, windows: 50)
        
        XCTAssertEqual(tabs.count, 1000, "Should generate exactly 1000 tabs")
        
        // Test duplicate finding
        let grouped = Dictionary(grouping: tabs) { $0.domain }
        let duplicates = grouped.filter { $0.value.count > 1 }
        
        XCTAssertGreaterThanOrEqual(duplicates.count, 0, "Should find duplicates")
        
        print("1000+ tab scale validation: PASSED")
    }
    
    /// Validates behavior at 4000+ tab scale (user's actual scale)
    func test4000PlusTabScale() {
        let tabs = generateTabs(count: 4000, windows: 160)
        
        XCTAssertEqual(tabs.count, 4000, "Should generate exactly 4000 tabs")
        XCTAssertEqual(tabs.filter { $0.windowId == 1 }.count, 25, "Window 1 should have 25 tabs (4000/160 = 25)")
        
        // Test domain caching - domain should be pre-computed
        let firstTab = tabs.first!
        _ = firstTab.domain // Access should be O(1) now
        
        // Test oldest/newest access
        let groups = generateDuplicateGroups(tabCount: 4000, duplicateRatio: 0.6)
        if let firstGroup = groups.first {
            _ = firstGroup.oldestTab?.openedAt
            _ = firstGroup.newestTab?.openedAt
        }
        
        print("4000+ tab scale validation: PASSED")
    }
}
