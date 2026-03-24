import XCTest
@testable import ChromeTabManager

final class SecurityTests: XCTestCase {

    func testSanitizeURL_validHTTPS() {
        let result = SecurityUtils.sanitizeURL("https://example.com/page")
        XCTAssertEqual(result, "https://example.com/page")
    }

    func testSanitizeURL_invalidScheme() {
        let result = SecurityUtils.sanitizeURL("ftp://example.com")
        XCTAssertNil(result)
    }

    func testSanitizeURL_rejectsJavascript() {
        let result = SecurityUtils.sanitizeURL("javascript:alert(1)")
        XCTAssertNil(result)
    }

    func testSanitizeTitle_stripsControlChars() {
        let input = "Hello\u{0000}World\u{0001}"
        let result = SecurityUtils.sanitizeTitle(input)
        XCTAssertFalse(result.contains("\u{0000}"))
        XCTAssertFalse(result.contains("\u{0001}"))
    }

    func testSanitizeTitle_limitsLength() {
        let longTitle = String(repeating: "A", count: 600)
        let result = SecurityUtils.sanitizeTitle(longTitle)
        XCTAssertLessThanOrEqual(result.count, 500)
    }

    func testURLPatternMatching_domain() {
        // Without patternType, domain matching uses suffix/contains logic
        let pattern = URLPattern(pattern: "youtube.com")
        XCTAssertTrue(pattern.matches("https://youtube.com/watch?v=123"))
        XCTAssertTrue(pattern.matches("https://www.youtube.com/watch?v=123"))
    }

    func testURLPatternMatching_wildcard() {
        let pattern = URLPattern(pattern: "*.github.com")
        XCTAssertTrue(pattern.matches("https://gist.github.com"))
        XCTAssertTrue(pattern.matches("https://api.github.com"))
    }

    func testURLPatternMatching_exact() {
        let pattern = URLPattern(pattern: "https://example.com/exact")
        XCTAssertTrue(pattern.matches("https://example.com/exact"))
        XCTAssertFalse(pattern.matches("https://example.com/other"))
    }

    func testCleanupRuleMatchesTabs() {
        let pattern = URLPattern(pattern: "youtube.com")
        let rule = CleanupRule(name: "YouTube", pattern: pattern, action: .close)
        let tab = TabInfo(
            id: "1", windowId: 1, tabIndex: 0,
            title: "YouTube", url: "https://youtube.com/watch",
            openedAt: Date()
        )
        let noMatchTab = TabInfo(
            id: "2", windowId: 1, tabIndex: 1,
            title: "Google", url: "https://google.com",
            openedAt: Date()
        )
        XCTAssertTrue(rule.matches(tab))
        XCTAssertFalse(rule.matches(noMatchTab))
    }

    func testExportManager_jsonFormat() {
        let tabs = [
            TabInfo(
                id: "1", windowId: 1, tabIndex: 0,
                title: "Test", url: "https://test.com",
                openedAt: Date()
            )
        ]
        let result = ExportManager.export(tabs: tabs, format: .json)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Test"))
        XCTAssertTrue(result.contains("https://test.com"))
    }

    func testMemoryProtection_secureWipeData() {
        var sensitive = Data("super-secret".utf8)
        MemoryProtection.secureWipe(&sensitive)
        XCTAssertTrue(sensitive.isEmpty)
    }

    func testMemoryProtection_secureWipeBytes() {
        var sensitive: [UInt8] = [1, 2, 3, 4, 5]
        MemoryProtection.secureWipe(&sensitive)
        XCTAssertTrue(sensitive.isEmpty)
    }

    func testMemoryProtection_constantTimeEquals() {
        let a = Data([0x01, 0x02, 0x03])
        let b = Data([0x01, 0x02, 0x03])
        let c = Data([0x01, 0x02, 0x04])
        XCTAssertTrue(MemoryProtection.constantTimeEquals(a, b))
        XCTAssertFalse(MemoryProtection.constantTimeEquals(a, c))
    }

    func testCodeSignatureVerifier_executionPath() {
        _ = CodeSignatureVerifier.verifyCurrentProcessSignature()
        _ = CodeSignatureVerifier.signingTeamIdentifier()
    }

    func testRuntimeProtection_reportGeneration() {
        let report = RuntimeProtection.evaluate()
        XCTAssertNotNil(report.generatedAt)
        _ = report.requiresMitigation
    }

    func testSecureEnclaveKeyManager_signingFlow() throws {
        let payload = Data("security-audit-payload".utf8)
        let signature = try SecureEnclaveKeyManager.sign(payload)
        XCTAssertFalse(signature.isEmpty)
    }

    func testSecureEnclaveKeyManager_keyProtectionModeIsResolvable() {
        _ = SecureEnclaveKeyManager.keyProtectionMode()
    }

    func testSecurityAuditLogger_writesTamperEvidentRecord() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("audit.jsonl", isDirectory: false)
        let logger = SecurityAuditLogger(fileURL: fileURL)
        await logger.log(
            category: "test",
            action: "event",
            severity: .info,
            details: ["a": "b"],
            signEvent: false
        )

        let data = try Data(contentsOf: fileURL)
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        XCTAssertEqual(lines.count, 1)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SecurityAuditEvent.self, from: Data(lines[0].utf8))
        XCTAssertEqual(event.category, "test")
        XCTAssertEqual(event.action, "event")
        XCTAssertFalse(event.recordHash.isEmpty)
    }
}
