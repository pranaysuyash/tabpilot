import Foundation

// RECOVERY ADDON: lightweight persistence for aggregate cleanup metrics.
@MainActor
final class StatisticsStoreRecovery: ObservableObject {
    struct Snapshot: Codable, Hashable {
        var totalScans: Int = 0
        var totalTabsScanned: Int = 0
        var totalDuplicatesDetected: Int = 0
        var totalTabsClosed: Int = 0
        var lastScanAt: Date?
    }

    @Published private(set) var snapshot = Snapshot()
    private let key = "recovery.statistics.snapshot"

    init() { load() }

    func recordScan(tabsScanned: Int, duplicates: Int, tabsClosed: Int) {
        snapshot.totalScans += 1
        snapshot.totalTabsScanned += max(0, tabsScanned)
        snapshot.totalDuplicatesDetected += max(0, duplicates)
        snapshot.totalTabsClosed += max(0, tabsClosed)
        snapshot.lastScanAt = Date()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }
        snapshot = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }
}
