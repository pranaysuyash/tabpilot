import XCTest
@testable import ChromeTabManager

@MainActor
final class HistoricalTimeTrackingTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testDailyTimeRecordCreation() {
        let record = DailyTimeRecord(
            date: "2024-03-26",
            totalActiveTimeMs: 3600000, // 1 hour
            domainTime: ["google.com": 1800000, "github.com": 1800000],
            tabCount: 5
        )
        
        XCTAssertEqual(record.date, "2024-03-26")
        XCTAssertEqual(record.totalActiveTimeSeconds, 3600.0)
        XCTAssertEqual(record.topDomains(limit: 2).count, 2)
    }
    
    func testDailyTimeRecordTopDomains() {
        let record = DailyTimeRecord(
            date: "2024-03-26",
            totalActiveTimeMs: 7200000, // 2 hours
            domainTime: [
                "google.com": 3600000,
                "github.com": 2400000,
                "stackoverflow.com": 1200000
            ],
            tabCount: 8
        )
        
        let topDomains = record.topDomains(limit: 2)
        XCTAssertEqual(topDomains.count, 2)
        XCTAssertEqual(topDomains[0].domain, "google.com")
        XCTAssertEqual(topDomains[0].seconds, 3600.0)
        XCTAssertEqual(topDomains[1].domain, "github.com")
    }
    
    func testHistoricalStatisticsAggregation() {
        let days = [
            DailyTimeRecord(date: "2024-03-24", totalActiveTimeMs: 3600000, domainTime: ["google.com": 3600000], tabCount: 3),
            DailyTimeRecord(date: "2024-03-25", totalActiveTimeMs: 7200000, domainTime: ["google.com": 3600000, "github.com": 3600000], tabCount: 5),
            DailyTimeRecord(date: "2024-03-26", totalActiveTimeMs: 5400000, domainTime: ["github.com": 5400000], tabCount: 4)
        ]
        
        let stats = HistoricalStatistics(days: days)
        
        // Test total time
        XCTAssertEqual(stats.totalTimeSeconds, 16200.0) // 4.5 hours total
        
        // Test average
        XCTAssertEqual(stats.averageDailyTimeSeconds, 5400.0) // 1.5 hours average
        
        // Test aggregated domains (sorted by time, highest first)
        let aggregated = stats.aggregatedDomainTime
        XCTAssertEqual(aggregated.count, 2)
        XCTAssertEqual(aggregated[0].domain, "github.com")
        XCTAssertEqual(aggregated[0].seconds, 9000.0) // 2.5 hours on github
        XCTAssertEqual(aggregated[1].domain, "google.com")
        XCTAssertEqual(aggregated[1].seconds, 7200.0) // 2 hours on google
    }
    
    func testHistoricalStatisticsTrendIncreasing() {
        // Last day is significantly higher than average
        let days = [
            DailyTimeRecord(date: "2024-03-24", totalActiveTimeMs: 1000000, domainTime: [:], tabCount: 1),
            DailyTimeRecord(date: "2024-03-25", totalActiveTimeMs: 1000000, domainTime: [:], tabCount: 1),
            DailyTimeRecord(date: "2024-03-26", totalActiveTimeMs: 5000000, domainTime: [:], tabCount: 1) // 5x higher
        ]
        
        let stats = HistoricalStatistics(days: days)
        
        if case .increasing(let pct) = stats.trend {
            XCTAssertTrue(pct > 10)
        } else {
            XCTFail("Expected increasing trend")
        }
    }
    
    func testHistoricalStatisticsTrendDecreasing() {
        // Last day is significantly lower than average
        let days = [
            DailyTimeRecord(date: "2024-03-24", totalActiveTimeMs: 5000000, domainTime: [:], tabCount: 1),
            DailyTimeRecord(date: "2024-03-25", totalActiveTimeMs: 5000000, domainTime: [:], tabCount: 1),
            DailyTimeRecord(date: "2024-03-26", totalActiveTimeMs: 1000000, domainTime: [:], tabCount: 1) // 5x lower
        ]
        
        let stats = HistoricalStatistics(days: days)
        
        if case .decreasing(let pct) = stats.trend {
            XCTAssertTrue(pct < -10)
        } else {
            XCTFail("Expected decreasing trend")
        }
    }
    
    func testHistoricalStatisticsTrendStable() {
        // Days are relatively consistent
        let days = [
            DailyTimeRecord(date: "2024-03-24", totalActiveTimeMs: 3600000, domainTime: [:], tabCount: 1),
            DailyTimeRecord(date: "2024-03-25", totalActiveTimeMs: 3700000, domainTime: [:], tabCount: 1),
            DailyTimeRecord(date: "2024-03-26", totalActiveTimeMs: 3600000, domainTime: [:], tabCount: 1)
        ]
        
        let stats = HistoricalStatistics(days: days)
        
        if case .stable = stats.trend {
            // Expected
        } else {
            XCTFail("Expected stable trend")
        }
    }
    
    func testHistoricalStatisticsTrendNoData() {
        let stats = HistoricalStatistics(days: [])
        
        if case .noData = stats.trend {
            // Expected
        } else {
            XCTFail("Expected no data trend for empty days")
        }
        
        let singleDayStats = HistoricalStatistics(days: [
            DailyTimeRecord(date: "2024-03-26", totalActiveTimeMs: 3600000, domainTime: [:], tabCount: 1)
        ])
        
        if case .noData = singleDayStats.trend {
            // Expected - need at least 2 days for trend
        } else {
            XCTFail("Expected no data trend for single day")
        }
    }
    
    func testTrendDescription() {
        let increasing = HistoricalStatistics.Trend.increasing(25.5)
        XCTAssertEqual(increasing.description, "↑ 25.5%")
        
        let decreasing = HistoricalStatistics.Trend.decreasing(15.3)
        XCTAssertEqual(decreasing.description, "↓ 15.3%")
        
        let stable = HistoricalStatistics.Trend.stable(3.2)
        XCTAssertEqual(stable.description, "→ 3.2%")
        
        let noData = HistoricalStatistics.Trend.noData
        XCTAssertEqual(noData.description, "-")
    }
}