import Foundation

struct TabTimeData: Codable, Sendable {
    let lastUpdated: Double
    let date: String
    let domainTime: [String: Double]
    let tabDetails: [String: TabDetail]
    
    struct TabDetail: Codable, Sendable {
        let url: String
        let domain: String
        let totalMs: Double
    }
}

actor TabTimeStore {
    static let shared = TabTimeStore()
    
    private var cached: TabTimeData?
    private var lastReadTime: Date?
    private let cacheInterval: TimeInterval = 5
    
    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("TabPilot/tab_time_data.json")
    }
    
    private init() {}
    
    func load() -> TabTimeData? {
        if let cached = cached,
           let lastRead = lastReadTime,
           Date().timeIntervalSince(lastRead) < cacheInterval {
            return cached
        }
        
        guard let data = try? Data(contentsOf: dataFileURL),
              let decoded = try? JSONDecoder().decode(TabTimeData.self, from: data) else {
            return nil
        }
        
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        guard decoded.date == String(today) else {
            cached = nil
            lastReadTime = Date()
            return nil
        }
        
        cached = decoded
        lastReadTime = Date()
        return decoded
    }
    
    func timeForDomain(_ domain: String) -> Double {
        guard let data = load() else { return 0 }
        return (data.domainTime[domain] ?? 0) / 1000.0
    }
    
    func topDomains(limit: Int = 10) -> [(domain: String, seconds: Double)] {
        guard let data = load() else { return [] }
        return data.domainTime
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (domain: $0.key, seconds: $0.value / 1000.0) }
    }
    
    func totalActiveTime() -> Double {
        guard let data = load() else { return 0 }
        return data.domainTime.values.reduce(0, +) / 1000.0
    }
    
    func isAvailable() -> Bool {
        return load() != nil
    }
    
    func invalidateCache() {
        cached = nil
        lastReadTime = nil
    }
}
