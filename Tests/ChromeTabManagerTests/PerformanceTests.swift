import XCTest
@testable import ChromeTabManager

final class PerformanceTests: XCTestCase {

    func testURLNormalizationPerformance() {
        let inputs = (0..<10_000).map {
            "https://www.example.com/path/\($0)?utm_source=test&utm_medium=email&id=\($0)#fragment"
        }

        measure {
            for input in inputs {
                _ = normalizeURL(input)
            }
        }
    }
}
