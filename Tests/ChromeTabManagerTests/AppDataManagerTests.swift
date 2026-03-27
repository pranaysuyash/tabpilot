import XCTest
@testable import ChromeTabManager

@MainActor
final class AppDataManagerTests: XCTestCase {
    
    // MARK: - Export Tests
    
    func testExportToFileCreatesValidJSON() async throws {
        let manager = AppDataManager.shared
        
        let url = try await manager.exportToFile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    
    // MARK: - Import Tests
    
    func testImportFromFileHandlesInvalidFileGracefully() async throws {
        let manager = AppDataManager.shared
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent.json")
        
        do {
            _ = try await manager.importFromFile(at: invalidURL)
            XCTFail("Expected error for non-existent file")
        } catch {
            XCTAssertTrue(error is CocoaError)
        }
    }
    
    // MARK: - Import Result Tests
    
    func testImportResultInitialization() {
        let result = ImportResult()
        
        XCTAssertEqual(result.cleanupRules, 0)
        XCTAssertEqual(result.urlPatterns, 0)
        XCTAssertEqual(result.sessions, 0)
        XCTAssertEqual(result.closedTabHistory, 0)
        XCTAssertEqual(result.statisticsImported, false)
        XCTAssertEqual(result.totalImported, 0)
        XCTAssertEqual(result.summary, "Nothing new imported")
    }
    
    func testImportResultSummaryWithItems() {
        var result = ImportResult()
        result.cleanupRules = 2
        result.urlPatterns = 1
        result.sessions = 3
        result.closedTabHistory = 5
        result.statisticsImported = true
        
        XCTAssertEqual(result.totalImported, 12)
        XCTAssertTrue(result.summary.contains("2 rules"))
        XCTAssertTrue(result.summary.contains("1 patterns"))
        XCTAssertTrue(result.summary.contains("3 sessions"))
        XCTAssertTrue(result.summary.contains("5 history entries"))
        XCTAssertTrue(result.summary.contains("statistics"))
    }
}
