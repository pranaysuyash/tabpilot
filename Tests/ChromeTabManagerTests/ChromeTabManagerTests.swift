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
        XCTAssertEqual(DuplicateViewMode.overall.description, "Show all duplicates grouped by URL")
        XCTAssertEqual(DuplicateViewMode.byWindow.description, "Group duplicates by which window they are in")
        XCTAssertEqual(DuplicateViewMode.byDomain.description, "Group duplicates by website domain")
        XCTAssertEqual(DuplicateViewMode.crossWindow.description, "Show only duplicates that exist in multiple windows")
    }
    
    func testViewModeIcons() {
        XCTAssertEqual(DuplicateViewMode.overall.icon, "doc.on.doc")
        XCTAssertEqual(DuplicateViewMode.byWindow.icon, "uiwindow.split.2x1")
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

    // MARK: - App Data Import/Export Tests

    @MainActor
    func testAppDataSnapshotRoundTripPreservesStatistics() throws {
        let stats = TabStatistics(
            totalTabsClosed: 10,
            duplicateTabsClosed: 4,
            sessionsCount: 2,
            lastSessionDate: Date(timeIntervalSince1970: 1_700_000_000),
            mostClosedDomains: ["example.com": 3],
            totalSavingsSeconds: 1_200,
            tabDebtScore: 82,
            tabDebtHistory: [TabDebtEntry(date: Date(timeIntervalSince1970: 1_700_000_100), tabCount: 42, duplicateCount: 7)],
            lastRecordedTabCount: 42,
            lastRecordedDate: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let snapshot = AppDataSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_200),
            appVersion: "1.0",
            schemaVersion: AppDataSnapshot.currentSchemaVersion,
            cleanupRules: [],
            urlPatterns: [],
            sessions: [],
            closedTabHistory: [],
            statistics: stats
        )

        let encoded = try snapshot.toJSON()
        let decoded = try AppDataSnapshot.fromJSON(encoded)

        XCTAssertEqual(decoded.schemaVersion, AppDataSnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded.statistics?.totalTabsClosed, 10)
        XCTAssertEqual(decoded.statistics?.mostClosedDomains["example.com"], 3)
        XCTAssertEqual(decoded.statistics?.tabDebtScore, 82)
    }

    @MainActor
    func testAppDataImportRejectsFutureSchemaVersion() throws {
        let snapshot = AppDataSnapshot(
            exportedAt: Date(),
            appVersion: "9.9",
            schemaVersion: AppDataSnapshot.currentSchemaVersion + 1,
            cleanupRules: [],
            urlPatterns: [],
            sessions: [],
            closedTabHistory: [],
            statistics: nil
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("future-schema-import.json")
        try snapshot.toJSON().write(to: url)

        XCTAssertThrowsError(try AppDataManager.shared.importFromFile(at: url)) { error in
            guard case AppDataImportError.unsupportedSchemaVersion = error else {
                return XCTFail("Expected unsupported schema version error, got: \(error)")
            }
        }
    }

    @MainActor
    func testAppDataImportMergeAndReplaceBehavior() throws {
        // Reset stores to deterministic baseline.
        CleanupRuleStore.shared.replaceAll([])
        URLPatternStore.shared.savePatterns([])
        SessionStore.shared.replaceAll([])
        ClosedTabHistoryStore.shared.clear()
        StatisticsStore.shared.reset()

        let existingRuleID = UUID()
        let existingPatternID = UUID()
        let existingSessionID = UUID()

        let existingRule = CleanupRule(
            id: existingRuleID,
            name: "Existing Rule",
            pattern: URLPattern(pattern: "*.existing.com"),
            action: .close,
            enabled: true
        )
        let existingPattern = URLPattern(id: existingPatternID, pattern: "*.existing-pattern.com")
        let existingSession = Session(id: existingSessionID, name: "Existing Session", tabs: [
            SessionTab(title: "Existing", url: "https://existing-session.com")
        ])

        CleanupRuleStore.shared.replaceAll([existingRule])
        URLPatternStore.shared.savePatterns([existingPattern])
        SessionStore.shared.replaceAll([existingSession])
        ClosedTabHistoryStore.shared.add(ClosedTabRecord(windowId: 1, url: "https://old-history.com", title: "old"))
        StatisticsStore.shared.save(TabStatistics(totalTabsClosed: 5))

        let importedRule = CleanupRule(
            id: UUID(),
            name: "Imported Rule",
            pattern: URLPattern(pattern: "*.imported.com"),
            action: .archive,
            enabled: true
        )
        let importedPattern = URLPattern(id: UUID(), pattern: "*.imported-pattern.com")
        let importedSession = Session(id: UUID(), name: "Imported Session", tabs: [
            SessionTab(title: "Imported", url: "https://imported-session.com")
        ])

        let mergeSnapshot = AppDataSnapshot(
            exportedAt: Date(),
            appVersion: "1.0",
            schemaVersion: AppDataSnapshot.currentSchemaVersion,
            cleanupRules: [existingRule, importedRule],
            urlPatterns: [existingPattern, importedPattern],
            sessions: [existingSession, importedSession],
            closedTabHistory: [ClosedTabRecord(windowId: 2, url: "https://merge-history.com", title: "merge")],
            statistics: TabStatistics(totalTabsClosed: 7)
        )

        let mergeURL = FileManager.default.temporaryDirectory.appendingPathComponent("merge-import.json")
        try mergeSnapshot.toJSON().write(to: mergeURL)
        let mergeResult = try AppDataManager.shared.importFromFile(at: mergeURL, replace: false)

        XCTAssertEqual(mergeResult.cleanupRules, 1)
        XCTAssertEqual(mergeResult.urlPatterns, 1)
        XCTAssertEqual(mergeResult.sessions, 1)
        XCTAssertTrue(mergeResult.statisticsImported)
        XCTAssertEqual(CleanupRuleStore.shared.rules.count, 2)
        XCTAssertEqual(URLPatternStore.shared.loadPatterns().count, 2)
        XCTAssertEqual(SessionStore.shared.sessions.count, 2)
        XCTAssertEqual(StatisticsStore.shared.load().totalTabsClosed, 12)

        let replaceSnapshot = AppDataSnapshot(
            exportedAt: Date(),
            appVersion: "1.0",
            schemaVersion: AppDataSnapshot.currentSchemaVersion,
            cleanupRules: [importedRule],
            urlPatterns: [importedPattern],
            sessions: [importedSession],
            closedTabHistory: [ClosedTabRecord(windowId: 3, url: "https://replace-history.com", title: "replace")],
            statistics: TabStatistics(totalTabsClosed: 99)
        )

        let replaceURL = FileManager.default.temporaryDirectory.appendingPathComponent("replace-import.json")
        try replaceSnapshot.toJSON().write(to: replaceURL)
        let replaceResult = try AppDataManager.shared.importFromFile(at: replaceURL, replace: true)

        XCTAssertEqual(replaceResult.cleanupRules, 1)
        XCTAssertEqual(replaceResult.urlPatterns, 1)
        XCTAssertEqual(replaceResult.sessions, 1)
        XCTAssertEqual(replaceResult.closedTabHistory, 1)
        XCTAssertTrue(replaceResult.statisticsImported)
        XCTAssertEqual(CleanupRuleStore.shared.rules.count, 1)
        XCTAssertEqual(URLPatternStore.shared.loadPatterns().count, 1)
        XCTAssertEqual(SessionStore.shared.sessions.count, 1)
        XCTAssertEqual(ClosedTabHistoryStore.shared.load().count, 1)
        XCTAssertEqual(StatisticsStore.shared.load().totalTabsClosed, 99)
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
