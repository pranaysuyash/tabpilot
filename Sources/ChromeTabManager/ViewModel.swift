import SwiftUI
import Combine
import AppKit
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class TabManagerViewModel: ObservableObject {
    private let scanUseCase: ScanTabsUseCaseProtocol
    private let closeUseCase: CloseTabsUseCaseProtocol
    private let exportUseCase: ExportTabsUseCaseProtocol
    private let eventBus: EventBus

    @Published var tabs: [TabInfo] = []
    @Published var windows: [WindowInfo] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var selectedTabIds: Set<String> = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanMessage = ""
    @Published var errorMessage: String?
    @Published var scanStats: ScanTelemetry?
    @Published var instances: [ChromeInstance] = []
    @Published var userAnalysis: UserAnalysis?
    // Raw search query — debounced into debouncedSearchQuery before filtering
    @Published var searchQuery = ""
    @Published private(set) var debouncedSearchQuery = ""
    @Published var toastMessage: String?
    @Published var showToast = false
    @Published var viewMode: DuplicateViewMode = .overall
    @Published var importPreviewTabs: [ImportTab] = []
    @Published var isImportResultPresented = false
    
    // Licensing
    @Published var licenseManager = LicenseManager.shared
    @Published var showPaywall = false
    
    // Confirmation dialog state
    @Published var showConfirmation = false
    @Published var confirmationTitle = ""
    @Published var confirmationMessage = ""
    private var confirmationAction: (() async -> Void)?
    
    // Undo snapshot state
    @Published var canUndo = false
    @Published var undoMessage = ""
    @Published var undoTimeRemaining: Double = 0
    private var lastClosedTabs: [ClosedTabInfo] = []
    private var undoTimer: Timer?
    private var undoCountdownTimer: Timer?
    
    struct ClosedTabInfo: Codable {
        let windowId: Int
        let url: String
        let title: String
        let closedAt: Date
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var scanTask: Task<Void, Never>?
    
    // Track first-seen timestamps for true "oldest" detection
    // Key: "windowId:index:url" for per-tab granularity
    // Note: Index may shift if tabs are closed, so this is "best effort"
    private var firstSeenTimestamps: [String: Date] = [:]
    private var timestampSaveTimer: Timer?
    private var timestampsDirty = false
    
    // Protected domains - never close these
    @Published var protectedDomains: [String] = ["mail.google.com", "calendar.google.com"] {
        didSet { saveProtectedDomains() }
    }
    private let sharedDefaults = UserDefaults(suiteName: "group.com.pranay.chrometabmanager")
    private let protectedDomainsKey = "protectedDomains"
    
    init(
        scanUseCase: ScanTabsUseCaseProtocol = DefaultScanTabsUseCase(),
        closeUseCase: CloseTabsUseCaseProtocol = DefaultCloseTabsUseCase(),
        exportUseCase: ExportTabsUseCaseProtocol = DefaultExportTabsUseCase(),
        eventBus: EventBus = .shared
    ) {
        self.scanUseCase = scanUseCase
        self.closeUseCase = closeUseCase
        self.exportUseCase = exportUseCase
        self.eventBus = eventBus
        setupNotifications()
        setupSearchDebounce()
        loadTimestamps()
        loadProtectedDomains()
        loadRecentArchives()
        // Start scheduled auto-cleanup (no-op if isEnabled == false)
        Task { @MainActor in AutoCleanupManager.shared.setup() }
    }
    
    // MARK: - Debounced Search
    
    /// Debounce the raw search query so filtering doesn't fire on every keystroke.
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.debouncedSearchQuery = query
                self?.invalidateDuplicateCache()
            }
            .store(in: &cancellables)
    }
    
    private func loadProtectedDomains() {
        if let saved = UserDefaults.standard.stringArray(forKey: protectedDomainsKey) {
            protectedDomains = saved
        }
    }
    
    private func saveProtectedDomains() {
        UserDefaults.standard.set(protectedDomains, forKey: protectedDomainsKey)
    }
    
    func isDomainProtected(_ url: String) -> Bool {
        guard let host = URL(string: url)?.host?.lowercased() else { return false }
        return protectedDomains.contains { host.contains($0) || $0.contains(host) }
    }
    
    func addProtectedDomain() {
        let trimmed = newProtectedDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty && !protectedDomains.contains(trimmed) else { return }
        protectedDomains.append(trimmed)
        newProtectedDomain = ""
        Task { await scan() }
    }
    
    func removeProtectedDomain(_ domain: String) {
        protectedDomains.removeAll { $0 == domain }
        Task { await scan() }
    }
    
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
        
        // Debounce: save after 2 seconds of inactivity
        timestampSaveTimer?.invalidate()
        timestampSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.saveTimestamps()
            }
        }
    }
    
    private func updateTimestamps(for scannedTabs: [TabInfo]) {
        let now = Date()
        var newTimestamps = 0
        
        for tab in scannedTabs {
            // Use composite key: windowId:index:url for per-tab granularity
            let key = "\(tab.windowId):\(tab.tabIndex):\(tab.url)"
            if firstSeenTimestamps[key] == nil {
                firstSeenTimestamps[key] = now
                newTimestamps += 1
            }
        }
        
        // Clean up old timestamps for tabs that no longer exist
        let currentKeys = Set(scannedTabs.map { "\($0.windowId):\($0.tabIndex):\($0.url)" })
        let beforeCount = firstSeenTimestamps.count
        firstSeenTimestamps = firstSeenTimestamps.filter { currentKeys.contains($0.key) }
        let removedCount = beforeCount - firstSeenTimestamps.count
        
        // Only schedule save if something changed
        if newTimestamps > 0 || removedCount > 0 {
            scheduleTimestampSave()
        }
    }
    
    private func firstSeenDate(for tab: TabInfo) -> Date {
        // Try exact match first
        let exactKey = "\(tab.windowId):\(tab.tabIndex):\(tab.url)"
        if let date = firstSeenTimestamps[exactKey] {
            return date
        }
        
        // Fallback: match by URL only (for backwards compatibility)
        let urlOnlyKey = "\(tab.windowId):\(tab.url)"
        if let date = firstSeenTimestamps[urlOnlyKey] {
            return date
        }
        
        return Date()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .scanTabs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.scan() }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .smartSelect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.smartSelect()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .closeSelected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Route through same gating pipeline as UI button
                self?.requestCloseSelected()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .showPreferences)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showPreferences = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .reviewPlan)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.requestCloseAllDuplicates(keepOldest: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .closeDuplicates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Hotkey: directly close all duplicates (keeps oldest) without review workflow
                Task { await self?.closeAllDuplicatesDirectly() }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .focusFilter)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Focus is handled directly by SuperUserView's @FocusState
                // via .onReceive(NotificationCenter.default.publisher(for: .focusFilter))
                // Nothing to do here in the ViewModel.
                _ = self // suppress unused warning
            }
            .store(in: &cancellables)
    }
    
    enum DuplicateViewMode: String, CaseIterable {
        case overall = "Overall"
        case byWindow = "By Window"
        case byDomain = "By Domain"
        case crossWindow = "Cross-Window"
        
        var icon: String {
            switch self {
            case .overall: return "doc.on.doc"
            case .byWindow: return "uiwindow.split.2x1"
            case .byDomain: return "globe"
            case .crossWindow: return "arrow.left.arrow.right"
            }
        }
        
        var description: String {
            switch self {
            case .overall: return "Show all duplicates grouped by URL"
            case .byWindow: return "Group duplicates by which window they are in"
            case .byDomain: return "Group duplicates by website domain"
            case .crossWindow: return "Show only duplicates that exist in multiple windows"
            }
        }
    }
    
    var config: PersonaConfig {
        userAnalysis?.config ?? PersonaConfig.forPersona(.standard)
    }
    
    // Cached filtered results
    private var cachedFilteredDuplicates: [DuplicateGroup]?
    private var cachedSearchQuery: String = ""
    private var cachedViewMode: DuplicateViewMode?
    
    var filteredDuplicates: [DuplicateGroup] {
        // Check cache validity against the debounced query (not raw keystrokes)
        if let cached = cachedFilteredDuplicates,
           cachedSearchQuery == debouncedSearchQuery,
           cachedViewMode == viewMode {
            return cached
        }
        
        let groups = duplicatesForCurrentMode
        let result: [DuplicateGroup]
        
        if debouncedSearchQuery.isEmpty {
            result = Array(groups.prefix(config.maxDuplicatesShown))
        } else {
            // Pre-compute lowercase search terms for performance
            let searchTerms = debouncedSearchQuery.lowercased().split(separator: " ").map(String.init)
            
            result = groups.filter { group in
                // Flatten all searchable text for this group once
                let groupTexts = group.tabs.flatMap { tab -> [String] in
                    [tab.title.lowercased(), tab.url.lowercased(), tab.domain.lowercased()]
                }
                return searchTerms.allSatisfy { term in
                    groupTexts.contains { $0.contains(term) }
                }
            }.prefix(config.maxDuplicatesShown).map { $0 }
        }
        
        // Update cache
        cachedFilteredDuplicates = result
        cachedSearchQuery = debouncedSearchQuery
        cachedViewMode = viewMode
        
        return result
    }
    
    // Invalidate cache when data changes
    func invalidateDuplicateCache() {
        cachedFilteredDuplicates = nil
    }
    
    var duplicatesForCurrentMode: [DuplicateGroup] {
        switch viewMode {
        case .overall:
            return duplicateGroups
        case .byWindow:
            return duplicateGroupsByWindow
        case .byDomain:
            return duplicateGroupsByDomain
        case .crossWindow:
            return crossWindowDuplicates
        }
    }
    
    // Duplicates grouped by window (for By Window view)
    var duplicateGroupsByWindow: [DuplicateGroup] {
        let windowIds = Set(duplicateGroups.flatMap { $0.tabs.map { $0.windowId } }).sorted()
        var result: [DuplicateGroup] = []
        
        for windowId in windowIds {
            let windowGroups = duplicateGroups.filter { group in
                group.tabs.contains { $0.windowId == windowId }
            }
            result.append(contentsOf: windowGroups)
        }
        
        return result
    }
    
    // Duplicates organized by domain (for By Domain view)
    var duplicateGroupsByDomain: [DuplicateGroup] {
        let domainGroups = Dictionary(grouping: duplicateGroups) { group in
            group.tabs.first?.domain ?? "unknown"
        }
        
        return domainGroups.sorted { $0.value.count > $1.value.count }.flatMap { $0.value }
    }
    
    // Only duplicates that exist in multiple windows (for Cross-Window view)
    var crossWindowDuplicates: [DuplicateGroup] {
        duplicateGroups.filter { group in
            let uniqueWindows = Set(group.tabs.map { $0.windowId })
            return uniqueWindows.count > 1
        }
    }
    
    var hasDuplicates: Bool {
        !duplicateGroups.isEmpty
    }
    
    func scan() async {
        // Cancel any in-flight scan before starting a new one
        scanTask?.cancel()
        scanTask = nil

        isScanning = true
        scanProgress = 0
        scanMessage = "Starting scan..."
        errorMessage = nil
        scanStats = nil

        // Capture task reference for cancellation support
        let task: Task<Void, Never> = Task { @MainActor [weak self] in
            guard let self else { return }
            await self._performScan()
        }
        scanTask = task
        await task.value
    }

    private func _performScan() async {
        do {
            // 30-second timeout around the full scan
            let result = try await withTimeout(seconds: 30) { [self] in
                try await scanUseCase.execute { [weak self] progress, message in
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
            
            // Store telemetry
            scanStats = result.telemetry
            
            // Show warning if there were failures
            if result.telemetry.windowsFailed > 0 {
                displayToast(message: "Warning: \(result.telemetry.windowsFailed) windows failed to scan")
            }
            
            // Update timestamps before storing tabs
            updateTimestamps(for: result.tabs)
            
            // Apply first-seen dates to tabs
            self.tabs = result.tabs.map { tab in
                TabInfo(
                    id: tab.id,
                    windowId: tab.windowId,
                    tabIndex: tab.tabIndex,
                    title: tab.title,
                    url: tab.url,
                    openedAt: firstSeenDate(for: tab)
                )
            }
            
            self.buildWindows()
            self.findDuplicates()
            self.instances = await ChromeController.shared.getInstances(knownTabCount: self.tabs.count)
            self.updateWidgetData()
            
            // AUTO-DETECT PERSONA
            self.userAnalysis = analyzeUser(tabs: self.tabs, duplicates: self.duplicateGroups)
            
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
    
    func closeSelectedTabs() async {
        let toClose = tabs.filter { selectedTabIds.contains($0.id) }
        guard !toClose.isEmpty else { return }
        
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
            return
        }
        
        // Save snapshot for undo
        saveSnapshot(for: toClose)
        
        // Group by window for deterministic batch closing
        let byWindow = Dictionary(grouping: toClose) { $0.windowId }
        var totalClosed = 0
        var totalFailed = 0
        var totalAmbiguous = 0
        
        for (windowId, windowTabs) in byWindow {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            let result = await closeUseCase.execute(windowId: windowId, targets: targets)
            totalClosed += result.closed
            totalFailed += result.failed
            totalAmbiguous += result.ambiguous
        }

        for tab in toClose.prefix(totalClosed) {
            eventBus.publish(TabClosedEvent(tabId: tab.id, timestamp: Date()))
        }
        
        if totalFailed > 0 {
            let userError = UserFacingError.tabCloseFailed(count: totalFailed)
            ErrorPresenter.shared.present(userError)
        }
        
        // Show appropriate feedback
        if totalAmbiguous > 0 {
            displayToast(message: "Closed \(totalClosed), \(totalAmbiguous) ambiguous (skipped)")
        } else if totalFailed > 0 {
            displayToast(message: "Closed \(totalClosed), failed \(totalFailed)")
        }
        
        selectedTabIds.removeAll()
        await scan()
    }
    
    func requestCloseSelected() {
        let toClose = tabs.filter { selectedTabIds.contains($0.id) }
        guard !toClose.isEmpty else { return }
        guard ensureCanClose(requestedCount: toClose.count) else { return }
        
        // Check if confirmation needed based on persona
        if config.confirmClose && toClose.count > 1 {
            confirmationTitle = "Close \(toClose.count) tabs?"
            confirmationMessage = closeConfirmationMessage(for: toClose.count)
            confirmationAction = { [weak self] in
                await self?.closeSelectedTabs()
            }
            showConfirmation = true
        } else {
            Task { await closeSelectedTabs() }
        }
    }
    
    // Review plan state
    @Published var showReviewPlan = false
    @Published var reviewPlanItems: [ReviewPlanItem] = []
    @Published var reviewPlanKeepPolicy = ""
    
    // Preferences state
    @Published var showPreferences = false
    @Published var isPreferencesOpen = false
    
    // Preference settings (using AppStorage)
    // NOTE: changes to matching prefs (ignoreTrackingParams, stripQueryParams)
    // automatically trigger a re-scan via Combine observers set up in setupNotifications().
    @AppStorage("defaultKeepPolicy") var defaultKeepPolicy: String = "first"
    @AppStorage("confirmDestructive") var confirmDestructive: Bool = true
    @AppStorage("ignoreTrackingParams") var ignoreTrackingParams: Bool = true {
        didSet { invalidateDuplicateCache(); findDuplicates() }
    }
    @AppStorage("stripQueryParams") var stripQueryParams: Bool = false {
        didSet { invalidateDuplicateCache(); findDuplicates() }
    }
    @AppStorage("maxDuplicatesDisplay") var maxDuplicatesDisplay: Int = 100
    @AppStorage(DefaultsKeys.defaultExportFormat) var defaultExportFormatRaw: String = ExportFormat.json.rawValue
    @AppStorage(DefaultsKeys.archiveLocationPath) var archiveLocationPath: String = ""
    @Published var newProtectedDomain: String = ""
    @Published var recentArchives: [URL] = []
    
    struct ReviewPlanItem: Identifiable {
        let id = UUID()
        let group: DuplicateGroup
        let keepTab: TabInfo
        let closeTabs: [TabInfo]
        var isIncluded: Bool = true
    }
    
    func requestCloseAllDuplicates(keepOldest: Bool = true) {
        let totalToClose = duplicateGroups.reduce(0) { $0 + $1.wastedCount }
        guard totalToClose > 0 else { return }
        guard ensureCanClose(requestedCount: totalToClose) else { return }
        
        // Build review plan
        reviewPlanItems = duplicateGroups.map { group in
            let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
            let keepTab = keepOldest ? sorted.first! : sorted.last!
            let closeTabs = keepOldest ? Array(sorted.dropFirst()) : Array(sorted.dropLast())
            return ReviewPlanItem(group: group, keepTab: keepTab, closeTabs: closeTabs)
        }
        reviewPlanKeepPolicy = keepOldest ? "Keep First Seen" : "Keep Last Seen"
        showReviewPlan = true
    }
    
    func executeReviewPlan() async {
        let itemsToClose = reviewPlanItems.filter { $0.isIncluded }
        let tabsToClose = itemsToClose.flatMap { $0.closeTabs }
        
        guard !tabsToClose.isEmpty else {
            displayToast(message: "No tabs selected to close")
            showReviewPlan = false
            return
        }
        guard ensureCanClose(requestedCount: tabsToClose.count) else {
            showReviewPlan = false
            return
        }
        
        // Save snapshot for undo
        saveSnapshot(for: tabsToClose)
        
        // Group by window for deterministic batch closing
        let byWindow = Dictionary(grouping: tabsToClose) { $0.windowId }
        var totalClosed = 0
        var totalFailed = 0
        var totalAmbiguous = 0
        
        for (windowId, windowTabs) in byWindow {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            let result = await closeUseCase.execute(windowId: windowId, targets: targets)
            totalClosed += result.closed
            totalFailed += result.failed
            totalAmbiguous += result.ambiguous
        }
        
        // Show appropriate feedback
        if totalAmbiguous > 0 {
            displayToast(message: "Closed \(totalClosed), \(totalAmbiguous) ambiguous (skipped)")
        } else if totalFailed > 0 {
            displayToast(message: "Closed \(totalClosed), failed \(totalFailed)")
        }
        
        showReviewPlan = false
        reviewPlanItems.removeAll()
        await scan()
    }
    
    func cancelReviewPlan() {
        showReviewPlan = false
        reviewPlanItems.removeAll()
    }
    
    func executeConfirmation() async {
        showConfirmation = false
        if let action = confirmationAction {
            await action()
        }
        confirmationAction = nil
    }
    
    func cancelConfirmation() {
        showConfirmation = false
        confirmationAction = nil
    }
    
    // MARK: - Undo System
    
    private func saveSnapshot(for tabs: [TabInfo]) {
        // Undo is available for licensed users.
        guard licenseManager.isLicensed else {
            clearUndo()
            return
        }
        
        lastClosedTabs = tabs.map { ClosedTabInfo(
            windowId: $0.windowId,
            url: $0.url,
            title: $0.title,
            closedAt: Date()
        )}
        eventBus.publish(ArchiveCreatedEvent(archiveId: UUID().uuidString, tabCount: tabs.count))
        canUndo = true
        undoMessage = "Closed \(tabs.count) tabs"
        undoTimeRemaining = 30

        // Per-second countdown
        undoCountdownTimer?.invalidate()
        undoCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.undoTimeRemaining -= 1
                if self.undoTimeRemaining <= 0 {
                    self.undoCountdownTimer?.invalidate()
                    self.undoCountdownTimer = nil
                }
            }
        }

        // Auto-expire undo after 30 seconds
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearUndo()
            }
        }
    }
    
    private func clearUndo() {
        lastClosedTabs.removeAll()
        canUndo = false
        undoMessage = ""
        undoTimeRemaining = 0
        undoTimer?.invalidate()
        undoTimer = nil
        undoCountdownTimer?.invalidate()
        undoCountdownTimer = nil
    }
    
    func undoLastClose() async {
        guard licenseManager.isLicensed else {
            showPaywall = true
            displayToast(message: "Undo is available for licensed users")
            return
        }
        
        guard !lastClosedTabs.isEmpty else {
            displayToast(message: "Nothing to undo")
            return
        }
        
        var restoredCount = 0
        var failedCount = 0
        
        // Reopen tabs in their original windows
        for closedTab in lastClosedTabs {
            let success = await ChromeController.shared.openTab(
                windowId: closedTab.windowId,
                url: closedTab.url
            )
            if success {
                restoredCount += 1
                try? await Task.sleep(nanoseconds: 100_000_000)
            } else {
                failedCount += 1
            }
        }
        
        if failedCount > 0 {
            displayToast(message: "Restored \(restoredCount), failed \(failedCount)")
        } else {
            displayToast(message: "Restored \(restoredCount) tabs")
        }
        
        clearUndo()
        await scan()
    }
    
    func dismissUndo() {
        clearUndo()
    }

    // MARK: - Tab Opening

    func openTab(windowId: Int, url: String) async -> Bool {
        await ChromeController.shared.openTab(windowId: windowId, url: url)
    }

    func openTabs(_ tabs: [TabInfo]) async -> Int {
        var opened = 0
        for tab in tabs {
            if await openTab(windowId: tab.windowId, url: tab.url) {
                opened += 1
            }
        }
        return opened
    }

    // MARK: - Domain Groups

    var domainGroups: [DomainGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.domain }
        return grouped.map { DomainGroup(domain: $0.key, tabs: $0.value) }
            .sorted { $0.tabs.count > $1.tabs.count }
    }

    // MARK: - Pruning Candidates

    var pruningCandidates: [TabInfo] {
        tabs.filter { tab in
            let age = Date().timeIntervalSince(tab.openedAt)
            return age > 86400 && duplicateGroups.contains { $0.tabs.contains(tab) }
        }
    }

    // MARK: - Domain Operations

    func closeTabsInDomain(_ domain: String) async {
        let domainTabs = tabs.filter { $0.domain == domain }
        let byWindow = Dictionary(grouping: domainTabs) { $0.windowId }
        var closed = 0
        for (windowId, windowTabs) in byWindow {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            let result = await closeUseCase.execute(windowId: windowId, targets: targets)
            closed += result.closed
        }
        displayToast(message: "Closed \(closed) tabs from \(domain)")
        await scan()
    }

    // MARK: - URL Patterns

    @Published var urlPatterns: [URLPattern] = []

    func addURLPattern(_ pattern: URLPattern) {
        URLPatternStore.shared.savePatterns(URLPatternStore.shared.loadPatterns() + [pattern])
        urlPatterns = URLPatternStore.shared.loadPatterns()
    }

    func checkURLPatterns(for tab: TabInfo) -> URLPattern? {
        urlPatterns.first { $0.matches(tab.url) }
    }

    // MARK: - Export Format

    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case html = "HTML"
        case markdown = "Markdown"

        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .html: return "html"
            case .markdown: return "md"
            }
        }
    }
    @Published var exportFormat: ExportFormat = .json

    var defaultExportFormat: ExportFormat {
        get { ExportFormat(rawValue: defaultExportFormatRaw) ?? .json }
        set { defaultExportFormatRaw = newValue.rawValue }
    }

    func exportCurrentTabs(format: ExportManager.ExportFormat) -> String {
        exportUseCase.export(tabs: tabs, format: format)
    }

    func exportCurrentDuplicates(format: ExportManager.ExportFormat) -> String {
        exportUseCase.exportDuplicates(groups: duplicateGroups, format: format)
    }

    func exportContent(for tabs: [TabInfo], format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return ExportManager.export(tabs: tabs, format: .markdown)
        case .html:
            return bookmarksHTML(for: tabs, title: "Chrome Tab Manager Export")
        case .json:
            return tabsJSON(for: tabs)
        }
    }

    func exportTabs(_ tabs: [TabInfo], format: ExportFormat, to url: URL) async {
        do {
            let content = exportContent(for: tabs, format: format)
            try content.write(to: url, atomically: true, encoding: .utf8)
            displayToast(message: "Exported \(tabs.count) tabs")
        } catch {
            let userError = UserFacingError.scanFailed(reason: "Export failed: \(error.localizedDescription)")
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
        }
    }

    func exportSelectedTabs(format: ExportFormat) {
        let selected = tabs.filter { selectedTabIds.contains($0.id) }
        guard !selected.isEmpty else {
            displayToast(message: "Select tabs to export first")
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "ChromeTabs-\(DateFormats.isoDateOnly.string(from: Date())).\(format.fileExtension)"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self?.exportTabs(selected, format: format, to: url) }
        }
    }

    func archiveTabs(_ tabs: [TabInfo], fileName: String?, format: ExportFormat, append: Bool) async {
        guard !tabs.isEmpty else {
            displayToast(message: "No tabs to archive")
            return
        }

        let baseName = (fileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? fileName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "archive-\(DateFormats.fileSafeDateTime.string(from: Date()))"
        let archiveURL = archiveDirectoryURL().appendingPathComponent("\(baseName).\(format.fileExtension)")

        do {
            try FileManager.default.createDirectory(at: archiveDirectoryURL(), withIntermediateDirectories: true)
            let content = exportContent(for: tabs, format: format)
            if append, FileManager.default.fileExists(atPath: archiveURL.path) {
                let current = (try? String(contentsOf: archiveURL, encoding: .utf8)) ?? ""
                try (current + "\n\n" + content).write(to: archiveURL, atomically: true, encoding: .utf8)
            } else {
                try content.write(to: archiveURL, atomically: true, encoding: .utf8)
            }
            addRecentArchive(archiveURL)
            displayToast(message: "Archived \(tabs.count) tabs")
        } catch {
            let userError = UserFacingError.archiveFailed
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
        }
    }

    func archiveSelectedTabs(fileName: String?, format: ExportFormat, append: Bool) {
        let selected = tabs.filter { selectedTabIds.contains($0.id) }
        Task { await archiveTabs(selected, fileName: fileName, format: format, append: append) }
    }

    func importTabs(from url: URL) async -> [ImportTab] {
        do {
            let data = try Data(contentsOf: url)
            let lowerName = url.lastPathComponent.lowercased()
            if lowerName.hasSuffix(".json"),
               let parsed = parseJSONTabs(data) {
                return parsed
            }

            if let text = String(data: data, encoding: .utf8) {
                if text.contains("<!DOCTYPE NETSCAPE-Bookmark-file-1>") || lowerName.hasSuffix(".html") || lowerName.hasSuffix(".htm") {
                    return parseBookmarksHTML(text)
                }
                if let parsed = parseJSONStringTabs(text) {
                    return parsed
                }
            }

            return []
        } catch {
            let userError = UserFacingError.scanFailed(reason: "Import failed: \(error.localizedDescription)")
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
            return []
        }
    }

    func openImportedTabs(_ importedTabs: [ImportTab]) async {
        guard !importedTabs.isEmpty else { return }
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
            return
        }

        let targetWindow = windows.first?.windowId ?? 1
        var opened = 0
        for tab in importedTabs {
            if await ChromeController.shared.openTab(windowId: targetWindow, url: tab.url) {
                opened += 1
            }
        }
        displayToast(message: "Opened \(opened) imported tabs")
        await scan()
    }

    // MARK: - Sessions

    @Published var sessions: [Session] = []

    // MARK: - Cleanup Rules

    @Published var cleanupRules: [CleanupRule] = []

    func loadCleanupRules() {
        cleanupRules = []
    }

    // MARK: - Health Metrics

    var healthMetrics: HealthMetrics? {
        guard !tabs.isEmpty else { return nil }
        return HealthMetrics.compute(from: tabs, duplicates: duplicateGroups)
    }

    // MARK: - Archive History

    @Published var showArchiveHistory = false
    @Published var closedTabHistory: ClosedTabHistoryStore?

    // MARK: - Move Tabs

    /// Moves tabs (by ID) to an existing Chrome window by reopening them there and closing originals.
    func moveTabsToWindow(tabIds: [String], targetWindowId: Int) async {
        guard await ChromeController.shared.isChromeRunning() else { return }

        let tabsToMove = tabs.filter { tabIds.contains($0.id) }
        guard !tabsToMove.isEmpty else { return }

        // Group by source window so we can close originals deterministically
        let bySourceWindow = Dictionary(grouping: tabsToMove) { $0.windowId }

        // Open each URL in the target window first
        var opened = 0
        for tab in tabsToMove {
            let success = await ChromeController.shared.openTab(windowId: targetWindowId, url: tab.url)
            if success { opened += 1 }
        }

        // Close originals from source windows (skip if source == target)
        for (sourceWindowId, windowTabs) in bySourceWindow where sourceWindowId != targetWindowId {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            _ = await closeUseCase.execute(windowId: sourceWindowId, targets: targets)
        }

        if opened > 0 {
            displayToast(message: "Moved \(opened) tab\(opened == 1 ? "" : "s") to window \(targetWindowId)")
        }
        await scan()
    }

    /// Moves tabs (by ID) to a new Chrome window.
    /// Note: requires AppleScript `make new window` which is not yet in ChromeController.
    /// Currently opens tabs in window 1 as a fallback — wire up openNewWindow when available.
    func moveTabsToNewWindow(tabIds: [String]) async {
        guard await ChromeController.shared.isChromeRunning() else { return }

        // Fallback: use first available window that isn't the source
        let tabsToMove = tabs.filter { tabIds.contains($0.id) }
        guard !tabsToMove.isEmpty else { return }

        let sourceIds = Set(tabsToMove.map { $0.windowId })
        let targetWindowId = windows.first { !sourceIds.contains($0.windowId) }?.windowId
        guard let targetId = targetWindowId else {
            displayToast(message: "No other window to move tabs to")
            return
        }
        await moveTabsToWindow(tabIds: tabIds, targetWindowId: targetId)
    }

    func closeAllDuplicates(keepOldest: Bool = true) async {
        let requested = duplicateGroups.reduce(0) { $0 + $1.wastedCount }
        guard ensureCanClose(requestedCount: requested) else { return }
        
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
            return
        }
        
        // Collect all tabs to close grouped by window for deterministic close
        var tabsByWindow: [Int: [TabInfo]] = [:]
        
        for group in duplicateGroups {
            let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
            let toClose = keepOldest ? Array(sorted.dropFirst()) : Array(sorted.dropLast())
            
            for tab in toClose {
                tabsByWindow[tab.windowId, default: []].append(tab)
            }
        }
        
        var totalClosed = 0
        var totalFailed = 0
        var totalAmbiguous = 0

        // Process each window's tabs in parallel using TaskGroup for throughput.
        // Within each window, closeTabsDeterministic already handles descending-index order.
        let windowResults = await withTaskGroup(
            of: (closed: Int, failed: Int, ambiguous: Int).self
        ) { group in
            for (windowId, windowTabs) in tabsByWindow {
                let targets = windowTabs.map { (url: $0.url, title: $0.title) }
                group.addTask {
                    await self.closeUseCase.execute(windowId: windowId, targets: targets)
                }
            }
            var results: [(closed: Int, failed: Int, ambiguous: Int)] = []
            for await result in group { results.append(result) }
            return results
        }

        for r in windowResults {
            totalClosed += r.closed
            totalFailed += r.failed
            totalAmbiguous += r.ambiguous
        }
        
        if totalFailed > 0 {
            let userError = UserFacingError.tabCloseFailed(count: totalFailed)
            ErrorPresenter.shared.present(userError)
        }
        
        if totalAmbiguous > 0 {
            displayToast(message: "Closed \(totalClosed), \(totalAmbiguous) ambiguous (skipped)")
        } else if totalFailed > 0 {
            displayToast(message: "Closed \(totalClosed), failed \(totalFailed) duplicates")
        } else {
            displayToast(message: "Closed \(totalClosed) duplicate tabs")
        }
        
        await scan()
    }

    /// Called by global hotkey Cmd+Shift+D — closes all duplicates directly without confirmation flow.
    func closeAllDuplicatesDirectly() async {
        await closeAllDuplicates(keepOldest: true)
    }

    func activateTab(_ tab: TabInfo) async {
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
            return
        }
        
        // Re-scan window to get current tab index with title disambiguation
        guard let currentIndex = await ChromeController.shared.findTabIndex(
            windowId: tab.windowId,
            url: tab.url,
            title: tab.title
        ) else {
            let userError = UserFacingError.tabNotFound
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
            return
        }

        do {
            try await ChromeController.shared.activateTab(
                windowId: tab.windowId,
                tabIndex: currentIndex
            )
            displayToast(message: "Switched to tab: \(tab.title.prefix(40))")
        } catch {
            let userError = UserFacingError.unknown(error)
            errorMessage = userError.errorDescription
            ErrorPresenter.shared.present(userError)
        }
    }

    func displayToast(message: String) {
        toastMessage = message
        showToast = true

        // Auto-hide after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            await MainActor.run {
                self.showToast = false
            }
        }
    }
    
    func smartSelect() {
        selectedTabIds.removeAll()
        for group in duplicateGroups {
            let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
            for tab in sorted.dropFirst() {
                selectedTabIds.insert(tab.id)
            }
        }
    }
    
    func selectAllExceptOldest(in group: DuplicateGroup) {
        let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
        for tab in sorted.dropFirst() {
            selectedTabIds.insert(tab.id)
        }
    }
    
    func selectAllExceptNewest(in group: DuplicateGroup) {
        let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
        for tab in sorted.dropLast() {
            selectedTabIds.insert(tab.id)
        }
    }
    
    func selectAll(in group: DuplicateGroup) {
        for tab in group.tabs {
            selectedTabIds.insert(tab.id)
        }
    }
    
    func clearSelection() {
        selectedTabIds.removeAll()
    }
    
    func toggleSelection(_ tab: TabInfo) {
        // Prevent selection of protected domains
        if isDomainProtected(tab.url) {
            displayToast(message: "Cannot select: protected domain")
            return
        }
        
        if selectedTabIds.contains(tab.id) {
            selectedTabIds.remove(tab.id)
        } else {
            selectedTabIds.insert(tab.id)
        }
    }

    // MARK: - Export/Import Helpers

    func archiveDirectoryURL() -> URL {
        if !archiveLocationPath.isEmpty {
            return URL(fileURLWithPath: archiveLocationPath, isDirectory: true)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ChromeTabManager/Archives", isDirectory: true)
    }

    func chooseArchiveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.archiveLocationPath = url.path
        }
    }

    func openArchiveDirectoryInFinder() {
        NSWorkspace.shared.open(archiveDirectoryURL())
    }

    func openArchiveFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func deleteArchiveFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            recentArchives.removeAll { $0 == url }
            saveRecentArchives()
        } catch {
            displayToast(message: "Failed to delete archive")
        }
    }

    private func loadRecentArchives() {
        let paths = UserDefaults.standard.stringArray(forKey: DefaultsKeys.recentArchivePaths) ?? []
        recentArchives = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func saveRecentArchives() {
        let paths = recentArchives.map(\.path)
        UserDefaults.standard.set(paths, forKey: DefaultsKeys.recentArchivePaths)
    }

    private func addRecentArchive(_ url: URL) {
        recentArchives.removeAll { $0 == url }
        recentArchives.insert(url, at: 0)
        if recentArchives.count > 20 {
            recentArchives = Array(recentArchives.prefix(20))
        }
        saveRecentArchives()
    }

    private func tabsJSON(for tabs: [TabInfo]) -> String {
        struct ExportContainer: Codable {
            struct ExportTab: Codable {
                let id: String
                let title: String
                let url: String
                let domain: String
                let openedAt: Date
                let windowId: Int
                let tabIndex: Int
            }
            let exportDate: Date
            let totalTabs: Int
            let tabs: [ExportTab]
            let version: String
            let app: String
        }

        let payload = ExportContainer(
            exportDate: Date(),
            totalTabs: tabs.count,
            tabs: tabs.map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    url: $0.url,
                    domain: $0.domain,
                    openedAt: $0.openedAt,
                    windowId: $0.windowId,
                    tabIndex: $0.tabIndex
                )
            },
            version: "1.0",
            app: "Chrome Tab Manager"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func bookmarksHTML(for tabs: [TabInfo], title: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        var lines: [String] = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>Bookmarks</TITLE>",
            "<H1>Bookmarks</H1>",
            "<DL><p>",
            "    <DT><H3 ADD_DATE=\"\(timestamp)\">\(title)</H3>",
            "    <DL><p>"
        ]
        for tab in tabs {
            let safeTitle = tab.title.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            lines.append("        <DT><A HREF=\"\(tab.url)\" ADD_DATE=\"\(timestamp)\">\(safeTitle)</A>")
        }
        lines += ["    </DL><p>", "</DL><p>"]
        return lines.joined(separator: "\n")
    }

    private func parseBookmarksHTML(_ text: String) -> [ImportTab] {
        let pattern = #"<A[^>]*HREF="([^"]+)"[^>]*>(.*?)</A>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let source = text as NSString
        let range = NSRange(location: 0, length: source.length)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let url = source.substring(with: match.range(at: 1))
            let title = decodeHTMLEntities(source.substring(with: match.range(at: 2)))
            guard URL(string: url) != nil else { return nil }
            return ImportTab(title: title, url: url, source: "bookmarks_html")
        }
    }

    private func parseJSONTabs(_ data: Data) -> [ImportTab]? {
        if let object = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = object as? [String: Any],
           let tabsArray = dict["tabs"] as? [[String: Any]] {
            return tabsArray.compactMap { item in
                guard let url = item["url"] as? String else { return nil }
                let title = (item["title"] as? String) ?? "Untitled"
                guard URL(string: url) != nil else { return nil }
                return ImportTab(title: title, url: url, source: "json")
            }
        }
        return nil
    }

    private func parseJSONStringTabs(_ text: String) -> [ImportTab]? {
        guard let data = text.data(using: .utf8) else { return nil }
        if let tabs = parseJSONTabs(data) {
            return tabs
        }
        if let object = try? JSONSerialization.jsonObject(with: data, options: []),
           let array = object as? [[String: Any]] {
            return array.compactMap { item in
                guard let url = item["url"] as? String else { return nil }
                let title = (item["title"] as? String) ?? "Untitled"
                guard URL(string: url) != nil else { return nil }
                return ImportTab(title: title, url: url, source: "json")
            }
        }
        return nil
    }

    private func decodeHTMLEntities(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

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
    
    private func findDuplicates() {
        // Filter out protected domains for all users
        let filteredTabs = tabs.filter { !isDomainProtected($0.url) }
        
        // Respect the user's stripQueryParams preference when normalising URLs
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
        
        // Invalidate cache since data changed
        invalidateDuplicateCache()
    }
    
    // MARK: - App Actions Confirmation
    
    private func ensureCanClose(requestedCount: Int) -> Bool {
        guard requestedCount > 0 else { return true }
        if !licenseManager.isLicensed {
            showPaywall = true
            displayToast(message: "Please unlock Chrome Tab Manager to close tabs.")
            return false
        }
        return true
    }
    
    private func closeConfirmationMessage(for count: Int) -> String {
        return "This will close \(count) selected tabs. You can undo this action for 30 seconds."
    }
}

extension ChromeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Google Chrome is not running"
        case .appleScriptFailed(let message):
            return "AppleScript error: \(message)"
        case .timeout:
            return "Operation timed out"
        case .ambiguousMatch(let message):
            return "Ambiguous match: \(message)"
        }
    }
}
