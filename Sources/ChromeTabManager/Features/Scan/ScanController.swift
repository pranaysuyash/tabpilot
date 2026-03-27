import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class ScanController {
    // MARK: - Dependencies
    private let scanUseCase: ScanTabsUseCaseProtocol
    private let eventBus: EventBus
    private let sharedDefaults = UserDefaults(suiteName: "group.com.pranay.chrometabmanager")
    
    // MARK: - Tab State
    var tabs: [TabInfo] = []
    private(set) var windows: [WindowInfo] = []
    private(set) var duplicateGroups: [DuplicateGroup] = []
    private var _windowsStorage: [WindowInfo] = []
    private var _duplicateGroupsStorage: [DuplicateGroup] = []
    
    // MARK: - Selection (delegated to TabSelectionController but stored here for cross-controller access)
    var selectedTabIds: Set<String> = []
    
    // MARK: - Scan State
    var selectedBrowser: Browser = .chrome
    var isScanning = false
    var scanProgress: Double = 0
    var scanMessage = ""
    var errorMessage: String?
    var scanStats: ScanTelemetry?
    private(set) var instances: [ChromeInstance] = []
    var userAnalysis: UserAnalysis?
    
    // MARK: - Timestamp Tracking
    private var firstSeenTimestamps: [String: Date] = [:]
    private var timestampSaveTimer: Timer?
    private var timestampsDirty = false
    
    // MARK: - Private State
    private var scanTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(
        scanUseCase: ScanTabsUseCaseProtocol = DefaultScanTabsUseCase(),
        eventBus: EventBus = .shared
    ) {
        self.scanUseCase = scanUseCase
        self.eventBus = eventBus
        loadTimestamps()
    }
    
    // MARK: - Public Methods
    
    func scan() async {
        scanTask?.cancel()
        scanTask = nil
        
        isScanning = true
        scanProgress = 0
        scanMessage = "Starting scan..."
        errorMessage = nil
        scanStats = nil
        
        let task: Task<Void, Never> = Task { @MainActor [weak self] in
            guard let self else { return }
            await self._performScan()
        }
        scanTask = task
        await task.value
    }
    
    func incrementalScan() async {
        guard !isScanning else { return }
        guard await selectedBrowser.controller.isRunning else {
            errorMessage = "\(selectedBrowser.rawValue) is not running"
            return
        }
        
        isScanning = true
        scanMessage = "Checking for changes..."
        scanProgress = 0.1
        
        do {
            let result = try await scanUseCase.execute(browser: selectedBrowser) { [weak self] progress, message in
                Task { @MainActor in
                    self?.scanMessage = message
                }
            }
            
            scanProgress = 0.8
            
            let changes = detectTabChanges(oldTabs: tabs, newTabs: result.tabs)
            tabs = result.tabs
            
            buildWindows()
            findDuplicates()
            if selectedBrowser == .chrome {
                instances = await ChromeController.shared.getInstances(knownTabCount: tabs.count)
            } else {
                instances = []
            }
            userAnalysis = analyzeUser(tabs: tabs, duplicates: duplicateGroups)
            scanStats = result.telemetry
            
            StatisticsStore.shared.recordTabDebt(
                tabCount: tabs.count,
                duplicateCount: duplicateGroups.reduce(0) { $0 + $1.wastedCount }
            )
            
            scanProgress = 1.0
            scanMessage = "Found \(changes.added.count) added, \(changes.removed.count) removed"
            
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { self.isScanning = false }
            }
            
        } catch ChromeError.notRunning {
            errorMessage = "\(selectedBrowser.rawValue) is not running"
        } catch {
            errorMessage = UserFacingError.scanFailed(reason: error.localizedDescription).errorDescription
            isScanning = false
        }
    }
    
    // MARK: - Private Scan Implementation
    
    private func _performScan() async {
        do {
            let result = try await withTimeout(seconds: 30) { [self] in
                try await scanUseCase.execute(browser: selectedBrowser) { [weak self] progress, message in
                    Task { @MainActor in
                        self?.scanProgress = Double(progress) / 100.0
                        self?.scanMessage = message
                    }
                }
            }
            
            guard !Task.isCancelled else {
                isScanning = false
                return
            }
            
            scanStats = result.telemetry
            
            if result.telemetry.windowsFailed > 0 {
                scanMessage = "Warning: \(result.telemetry.windowsFailed) windows failed to scan"
            }
            
            tabs = atomicallyProcessTabsWithTimestamps(result.tabs)
            buildWindows()
            findDuplicates()
            if selectedBrowser == .chrome {
                instances = await ChromeController.shared.getInstances(knownTabCount: tabs.count)
            } else {
                instances = []
            }
            updateWidgetData()
            
            userAnalysis = analyzeUser(tabs: tabs, duplicates: duplicateGroups)
            
            StatisticsStore.shared.recordTabDebt(
                tabCount: tabs.count,
                duplicateCount: duplicateGroups.reduce(0) { $0 + $1.wastedCount }
            )
            
        } catch ChromeError.notRunning {
            let userError = UserFacingError.chromeNotRunning
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
        } catch is CancellationError {
            SecureLogger.info("Scan cancelled")
        } catch let error as ChromeError {
            errorMessage = error.localizedDescription
            ErrorPresenter.shared.present(error)
        } catch {
            let userError = UserFacingError.scanFailed(reason: error.localizedDescription)
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
        }
        
        isScanning = false
    }
    
    // MARK: - Tab Change Detection
    
    struct TabChanges {
        let added: [TabInfo]
        let removed: [TabInfo]
        let updated: [TabInfo]
        let moved: [(from: TabInfo, to: TabInfo)]
        
        var isEmpty: Bool { added.isEmpty && removed.isEmpty && updated.isEmpty && moved.isEmpty }
    }
    
    private func detectTabChanges(oldTabs: [TabInfo], newTabs: [TabInfo]) -> TabChanges {
        let oldById = Dictionary(uniqueKeysWithValues: oldTabs.map { ($0.id, $0) })
        let newById = Dictionary(uniqueKeysWithValues: newTabs.map { ($0.id, $0) })
        
        let oldIds = Set(oldById.keys)
        let newIds = Set(newById.keys)
        
        let addedIds = newIds.subtracting(oldIds)
        let added = addedIds.compactMap { newById[$0] }
        
        let removedIds = oldIds.subtracting(newIds)
        let removed = removedIds.compactMap { oldById[$0] }
        
        let commonIds = oldIds.intersection(newIds)
        
        var updated: [TabInfo] = []
        var moved: [(from: TabInfo, to: TabInfo)] = []
        
        for id in commonIds {
            guard let oldTab = oldById[id], let newTab = newById[id] else { continue }
            
            if oldTab.windowId != newTab.windowId || oldTab.tabIndex != newTab.tabIndex {
                moved.append((from: oldTab, to: newTab))
            } else if oldTab.title != newTab.title || oldTab.url != newTab.url {
                updated.append(newTab)
            }
        }
        
        return TabChanges(added: added, removed: removed, updated: updated, moved: moved)
    }
    
    // MARK: - Window Building
    
    private func buildWindows() {
        let grouped = Dictionary(grouping: tabs) { $0.windowId }
        windows = grouped.map { windowId, tabs in
            WindowInfo(
                windowId: windowId,
                tabCount: tabs.count,
                tabs: tabs.sorted { $0.tabIndex < $1.tabIndex },
                activeTabIndex: 1
            )
        }.sorted { $0.windowId < $1.windowId }
    }
    
    // MARK: - Duplicate Finding
    
    private func findDuplicates() {
        let filteredTabs = tabs.filter { !isDomainProtected($0.url) }
        
        let grouped = Dictionary(grouping: filteredTabs) { tab in
            normalizeURL(tab.url, stripQuery: stripQueryParams, filterTracking: ignoreTrackingParams)
        }
        let duplicates = grouped.filter { $0.value.count > 1 }
        
        duplicateGroups = duplicates.map { url, tabs in
            DuplicateGroup(
                normalizedUrl: url,
                displayUrl: tabs.first?.url ?? url,
                tabs: tabs.sorted { $0.openedAt < $1.openedAt }
            )
        }.sorted { $0.tabs.count > $1.tabs.count }
    }
    
    // MARK: - Timestamp Management
    
    private func loadTimestamps() {
        if let data = UserDefaults.standard.data(forKey: "tabTimestamps"),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            firstSeenTimestamps = decoded
        }
    }
    
    private func saveTimestamps() {
        guard timestampsDirty else { return }
        
        if let encoded = try? JSONEncoder().encode(firstSeenTimestamps) {
            UserDefaults.standard.set(encoded, forKey: "tabTimestamps")
        }
        timestampsDirty = false
    }
    
    private func scheduleTimestampSave() {
        timestampsDirty = true
        
        timestampSaveTimer?.invalidate()
        timestampSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.saveTimestamps()
            }
        }
    }
    
    private func atomicallyProcessTabsWithTimestamps(_ scannedTabs: [TabInfo]) -> [TabInfo] {
        let now = Date()
        var newTimestamps = 0
        var updatedTabs: [TabInfo] = []
        
        for tab in scannedTabs {
            let key = "\(tab.windowId):\(tab.tabIndex):\(tab.url)"
            
            let openedAt: Date
            if let existingDate = firstSeenTimestamps[key] {
                openedAt = existingDate
            } else {
                firstSeenTimestamps[key] = now
                openedAt = now
                newTimestamps += 1
            }
            
            updatedTabs.append(TabInfo(
                id: tab.id,
                windowId: tab.windowId,
                tabIndex: tab.tabIndex,
                title: tab.title,
                url: tab.url,
                openedAt: openedAt
            ))
        }
        
        let currentKeys = Set(scannedTabs.map { "\($0.windowId):\($0.tabIndex):\($0.url)" })
        let beforeCount = firstSeenTimestamps.count
        firstSeenTimestamps = firstSeenTimestamps.filter { currentKeys.contains($0.key) }
        let removedCount = beforeCount - firstSeenTimestamps.count
        
        if newTimestamps > 0 || removedCount > 0 {
            scheduleTimestampSave()
        }
        
        return updatedTabs
    }
    
    // MARK: - Widget Data
    
    private func updateWidgetData() {
        sharedDefaults?.set(tabs.count, forKey: "widget.totalTabs")
        sharedDefaults?.set(duplicateGroups.count, forKey: "widget.duplicateGroups")
        sharedDefaults?.set(duplicateGroups.reduce(0) { $0 + $1.wastedCount }, forKey: "widget.wastedTabs")
        sharedDefaults?.set(windows.count, forKey: "widget.windows")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "widget.lastUpdated")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    // MARK: - Helpers
    
    func isDomainProtected(_ url: String) -> Bool {
        guard let host = URL(string: url)?.host?.lowercased() else { return false }
        let protectedDomains = UserDefaults.standard.stringArray(forKey: "protectedDomains") ?? ["mail.google.com", "calendar.google.com"]
        return protectedDomains.contains { domain in
            let normalized = domain.lowercased()
            return host == normalized || host.hasSuffix(".\(normalized)")
        }
    }
    
    private var stripQueryParams: Bool {
        UserDefaults.standard.bool(forKey: "stripQueryParams")
    }
    
    private var ignoreTrackingParams: Bool {
        UserDefaults.standard.bool(forKey: "ignoreTrackingParams")
    }
    
    func invalidateDuplicateCache() {
        // Placeholder - cache invalidation handled by TabSelectionController
    }
    
    // MARK: - Computed Properties
    
    var hasDuplicates: Bool {
        !duplicateGroups.isEmpty
    }
    
    var config: PersonaConfig {
        userAnalysis?.config ?? PersonaConfig.forPersona(.standard)
    }
    
    var healthMetrics: HealthMetrics? {
        guard !tabs.isEmpty else { return nil }
        return HealthMetrics.compute(from: tabs, duplicates: duplicateGroups)
    }
    
    var domainGroups: [DomainGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.domain }
        return grouped.map { DomainGroup(domain: $0.key, tabs: $0.value) }
            .sorted { $0.tabs.count > $1.tabs.count }
    }
    
    var pruningCandidates: [TabInfo] {
        tabs.filter { tab in
            let age = Date().timeIntervalSince(tab.openedAt)
            return age > 86400 && duplicateGroups.contains { $0.tabs.contains(tab) }
        }
    }
}
