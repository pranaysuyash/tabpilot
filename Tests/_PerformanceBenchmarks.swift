import Foundation
import XCTest
@testable import ChromeTabManager

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
    
    private let userAgents = [
        "Chrome", "Safari", "Firefox", "Edge", "Brave"
    ]
    
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
                profileName: userAgents.randomElement() ?? "default"
            )
            tabs.append(tab)
        }
        
        return tabs
    }
    
    func generateDuplicateGroups(tabCount: Int, duplicateRatio: Double) -> [DuplicateGroup] {
        let uniqueUrlCount = Int(Double(tabCount) * (1.0 - duplicateRatio))
        let duplicateCount = tabCount - uniqueUrlCount
        
        var groups: [DuplicateGroup] = []
        
        for i in 0..<uniqueUrlCount {
            let domain = commonDomains.randomElement()!
            let path = urlPaths.randomElement()!
            let url = "https://\(domain)/\(path)/unique-\(i)"
            let title = "Unique Page \(i)"
            
            let tab = TabInfo(
                id: UUID().uuidString,
                windowId: i % 5 + 1,
                tabIndex: i % 10 + 1,
                title: title,
                url: url,
                openedAt: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )
            
            groups.append(DuplicateGroup(
                normalizedUrl: url,
                displayUrl: url,
                tabs: [tab]
            ))
        }
        
        let tabsPerDuplicateGroup = 3
        let duplicateGroupCount = duplicateCount / tabsPerDuplicateGroup
        
        for i in 0..<duplicateGroupCount {
            let domain = commonDomains.randomElement()!
            let path = urlPaths.randomElement()!
            let baseUrl = "https://\(domain)/\(path)/dup-\(i)"
            
            var tabs: [TabInfo] = []
            for j in 0..<tabsPerDuplicateGroup {
                let fbclid = Bool.random() ? "&fbclid=abc\(j)" : ""
                let url = baseUrl + fbclid
                
                let tab = TabInfo(
                    id: UUID().uuidString,
                    windowId: (i + j) % 5 + 1,
                    tabIndex: j + 1,
                    title: "Duplicate \(i) Tab \(j)",
                    url: url,
                    openedAt: Date().addingTimeInterval(-Double(j * 3600))
                )
                tabs.append(tab)
            }
            
            groups.append(DuplicateGroup(
                normalizedUrl: baseUrl,
                displayUrl: baseUrl,
                tabs: tabs
            ))
        }
        
        return groups
    }
    
    // MARK: - Duplicate Grouping Benchmark
    
    func benchmarkDuplicateFinding(tabs: Int) {
        let testTabs = generateTabs(count: tabs, windows: min(tabs / 10, 50))
        
        measure {
            let filteredTabs = testTabs.filter { tab in
                guard let host = URL(string: tab.url)?.host?.lowercased() else { return true }
                let protectedDomains = UserDefaults.standard.stringArray(forKey: "protectedDomains") ?? ["mail.google.com", "calendar.google.com"]
                return !protectedDomains.contains { host.contains($0) || $0.contains(host) }
            }
            
            let grouped = Dictionary(grouping: filteredTabs) { tab in
                normalizeURL(tab.url, stripQuery: false, filterTracking: true)
            }
            
            let duplicates = grouped.filter { $0.value.count > 1 }
            
            _ = duplicates.map { url, tabs in
                DuplicateGroup(normalizedUrl: url, displayUrl: tabs.first?.url ?? url, tabs: tabs)
            }
        }
    }
    
    func testDuplicateFinding100Tabs() {
        benchmarkDuplicateFinding(tabs: 100)
    }
    
    func testDuplicateFinding500Tabs() {
        benchmarkDuplicateFinding(tabs: 500)
    }
    
    func testDuplicateFinding1000Tabs() {
        benchmarkDuplicateFinding(tabs: 1000)
    }
    
    func testDuplicateFinding2000Tabs() {
        benchmarkDuplicateFinding(tabs: 2000)
    }
    
    func testDuplicateFinding4000Tabs() {
        benchmarkDuplicateFinding(tabs: 4000)
    }
    
    // MARK: - Data Model Benchmarks
    
    func benchmarkDomainAccess(tabs: Int) {
        let testTabs = generateTabs(count: tabs, windows: 20)
        
        measure {
            var total = ""
            for tab in testTabs {
                total += tab.domain
            }
            _ = total
        }
    }
    
    func testDomainAccess100Tabs() {
        benchmarkDomainAccess(tabs: 100)
    }
    
    func testDomainAccess500Tabs() {
        benchmarkDomainAccess(tabs: 500)
    }
    
    func testDomainAccess1000Tabs() {
        benchmarkDomainAccess(tabs: 1000)
    }
    
    func testDomainAccess2000Tabs() {
        benchmarkDomainAccess(tabs: 2000)
    }
    
    func benchmarkOldestNewestTab(groups: Int) {
        let duplicateGroups = generateDuplicateGroups(tabCount: groups * 3, duplicateRatio: 0.8)
        
        measure {
            for group in duplicateGroups {
                _ = group.oldestTab
                _ = group.newestTab
            }
        }
    }
    
    func testOldestNewest100Groups() {
        benchmarkOldestNewestTab(groups: 100)
    }
    
    func testOldestNewest500Groups() {
        benchmarkOldestNewestTab(groups: 500)
    }
    
    func testOldestNewest1000Groups() {
        benchmarkOldestNewestTab(groups: 1000)
    }
    
    func benchmarkSorting(tabs: Int) {
        var testTabs = generateTabs(count: tabs, windows: 20)
        
        measure {
            testTabs.sort { $0.openedAt > $1.openedAt }
            testTabs.sort { $0.domain < $1.domain }
            testTabs.sort { $0.title < $1.title }
        }
    }
    
    func testSorting100Tabs() {
        benchmarkSorting(tabs: 100)
    }
    
    func testSorting500Tabs() {
        benchmarkSorting(tabs: 500)
    }
    
    func testSorting1000Tabs() {
        benchmarkSorting(tabs: 1000)
    }
    
    func testSorting2000Tabs() {
        benchmarkSorting(tabs: 2000)
    }
    
    func testSorting4000Tabs() {
        benchmarkSorting(tabs: 4000)
    }
    
    // MARK: - Memory Estimation
    
    func testMemoryEstimation4000Tabs() {
        let tabs = generateTabs(count: 4000, windows: 50)
        
        var totalSize = 0
        
        for tab in tabs {
            let idSize = tab.id.utf8.count
            let titleSize = tab.title.utf8.count
            let urlSize = tab.url.utf8.count
            let profileSize = tab.profileName.utf8.count
            let overhead = 80
            
            totalSize += idSize + titleSize + urlSize + profileSize + overhead
        }
        
        let tabMemoryKB = Double(totalSize) / 1024.0
        let tabMemoryMB = tabMemoryKB / 1024.0
        
        XCTAssertGreaterThan(tabMemoryMB, 0, "Should estimate tab memory")
        print("Estimated Tab Memory for 4000 tabs: \(String(format: "%.2f", tabMemoryMB)) MB")
    }
    
    func testMemoryEstimation500DuplicateGroups() {
        let groups = generateDuplicateGroups(tabCount: 1500, duplicateRatio: 0.7)
        
        var totalSize = 0
        
        for group in groups {
            let urlSize = group.normalizedUrl.utf8.count
            let displaySize = group.displayUrl.utf8.count
            let overhead = 64
            
            for tab in group.tabs {
                let idSize = tab.id.utf8.count
                let titleSize = tab.title.utf8.count
                let urlSize = tab.url.utf8.count
                let tabOverhead = 80
                totalSize += idSize + titleSize + urlSize + tabOverhead
            }
            
            totalSize += urlSize + displaySize + overhead
        }
        
        let memoryKB = Double(totalSize) / 1024.0
        let memoryMB = memoryKB / 1024.0
        
        XCTAssertGreaterThan(memoryMB, 0, "Should estimate duplicate group memory")
        print("Estimated Duplicate Group Memory for 500 groups: \(String(format: "%.2f", memoryMB)) MB")
    }
    
    func testMemoryEstimationCombined() {
        let tabs = generateTabs(count: 4000, windows: 50)
        let groups = generateDuplicateGroups(tabCount: 2000, duplicateRatio: 0.6)
        
        var tabSize = 0
        for tab in tabs {
            tabSize += tab.id.utf8.count + tab.title.utf8.count + tab.url.utf8.count + tab.profileName.utf8.count + 80
        }
        
        var groupSize = 0
        for group in groups {
            groupSize += group.normalizedUrl.utf8.count + group.displayUrl.utf8.count + 64
            for tab in group.tabs {
                groupSize += tab.id.utf8.count + tab.title.utf8.count + tab.url.utf8.count + 80
            }
        }
        
        let totalSize = tabSize + groupSize
        let totalMB = (Double(totalSize) / 1024.0) / 1024.0
        
        print("Total Estimated Memory (4000 tabs + 500+ groups): \(String(format: "%.2f", totalMB)) MB")
        
        XCTAssertGreaterThan(totalMB, 5.0, "Should have meaningful memory footprint")
    }
    
    // MARK: - Scale Stress Test
    
    func test500TabScaleStress() {
        let tabs = generateTabs(count: 500, windows: 10)
        
        let filtered = tabs.filter { tab in
            guard let host = URL(string: tab.url)?.host?.lowercased() else { return true }
            return !["mail.google.com", "calendar.google.com"].contains { host.contains($0) || $0.contains(host) }
        }
        
        let grouped = Dictionary(grouping: filtered) { tab in
            normalizeURL(tab.url, stripQuery: false, filterTracking: true)
        }
        
        let duplicates = grouped.filter { $0.value.count > 1 }
        
        let groups: [DuplicateGroup] = duplicates.map { url, tabs in
            DuplicateGroup(normalizedUrl: url, displayUrl: tabs.first?.url ?? url, tabs: tabs)
        }
        let sorted = groups.sorted { $0.tabs.count > $1.tabs.count }
        
        var totalWasted = 0
        for group in sorted {
            totalWasted += group.wastedCount
        }
        
        XCTAssertEqual(filtered.count, 500)
        XCTAssertEqual(duplicates.count, sorted.count)
        print("500 Tab Scale: Found \(sorted.count) duplicate groups, \(totalWasted) wasted tabs")
    }
    
    func testLargeScaleConsistency() {
        let small = generateTabs(count: 100, windows: 5)
        let large = generateTabs(count: 4000, windows: 50)
        
        let smallFiltered = small.filter { tab in
            guard let host = URL(string: tab.url)?.host?.lowercased() else { return true }
            return !["mail.google.com", "calendar.google.com"].contains { host.contains($0) || $0.contains(host) }
        }
        
        let largeFiltered = large.filter { tab in
            guard let host = URL(string: tab.url)?.host?.lowercased() else { return true }
            return !["mail.google.com", "calendar.google.com"].contains { host.contains($0) || $0.contains(host) }
        }
        
        XCTAssertEqual(smallFiltered.count, 100)
        XCTAssertEqual(largeFiltered.count, 4000)
        
        let smallDuplicates = Dictionary(grouping: smallFiltered) { normalizeURL($0.url, stripQuery: false, filterTracking: true) }.filter { $0.value.count > 1 }
        let largeDuplicates = Dictionary(grouping: largeFiltered) { normalizeURL($0.url, stripQuery: false, filterTracking: true) }.filter { $0.value.count > 1 }
        
        XCTAssertGreaterThanOrEqual(largeDuplicates.count, smallDuplicates.count)
        
        print("Small scale: \(smallDuplicates.count) groups, Large scale: \(largeDuplicates.count) groups")
    }
}