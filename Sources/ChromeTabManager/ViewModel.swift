import SwiftUI
import Combine

@MainActor
class TabManagerViewModel: ObservableObject {
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
    private var lastClosedTabs: [ClosedTabInfo] = []
    private var undoTimer: Timer?
    
    struct ClosedTabInfo: Codable {
        let windowId: Int
        let url: String
        let title: String
        let closedAt: Date
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
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
    private let protectedDomainsKey = "protectedDomains"
    
    init() {
        setupNotifications()
        setupSearchDebounce()
        loadTimestamps()
        loadProtectedDomains()
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
        isScanning = true
        scanProgress = 0
        scanMessage = "Starting scan..."
        errorMessage = nil
        scanStats = nil
        
        do {
            let result = try await ChromeController.shared.scanAllTabsFast { [weak self] progress, message in
                Task { @MainActor in
                    self?.scanProgress = Double(progress) / 100.0
                    self?.scanMessage = message
                }
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
            
            // AUTO-DETECT PERSONA
            self.userAnalysis = analyzeUser(tabs: self.tabs, duplicates: self.duplicateGroups)
            
        } catch ChromeError.notRunning {
            errorMessage = "Chrome is not running"
        } catch let error as ChromeError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to scan: \(error.localizedDescription)"
        }
        
        isScanning = false
    }
    
    func closeSelectedTabs() async {
        let toClose = tabs.filter { selectedTabIds.contains($0.id) }
        guard !toClose.isEmpty else { return }
        
        // Save snapshot for undo
        saveSnapshot(for: toClose)
        
        // Group by window for deterministic batch closing
        let byWindow = Dictionary(grouping: toClose) { $0.windowId }
        var totalClosed = 0
        var totalFailed = 0
        var totalAmbiguous = 0
        
        for (windowId, windowTabs) in byWindow {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            let result = await ChromeController.shared.closeTabsDeterministic(
                windowId: windowId,
                targets: targets
            )
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
    @Published var newProtectedDomain: String = ""
    
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
            let result = await ChromeController.shared.closeTabsDeterministic(
                windowId: windowId,
                targets: targets
            )
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
        canUndo = true
        undoMessage = "Closed \(tabs.count) tabs"
        
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
        undoTimer?.invalidate()
        undoTimer = nil
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
            let result = await ChromeController.shared.closeTabsDeterministic(windowId: windowId, targets: targets)
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
    }
    @Published var exportFormat: ExportFormat = .json

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

    func moveTabsToWindow(tabIds: [String], targetWindowId: Int) async {

    }

    func moveTabsToNewWindow(tabIds: [String]) async {

    }

    func closeAllDuplicates(keepOldest: Bool = true) async {
        let requested = duplicateGroups.reduce(0) { $0 + $1.wastedCount }
        guard ensureCanClose(requestedCount: requested) else { return }
        
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
        
        // Close each window's tabs deterministically
        for (windowId, windowTabs) in tabsByWindow {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            let result = await ChromeController.shared.closeTabsDeterministic(
                windowId: windowId,
                targets: targets
            )
            totalClosed += result.closed
            totalFailed += result.failed
            totalAmbiguous += result.ambiguous
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
    
    func activateTab(_ tab: TabInfo) async {
        // Re-scan window to get current tab index with title disambiguation
        guard let currentIndex = await ChromeController.shared.findTabIndex(
            windowId: tab.windowId,
            url: tab.url,
            title: tab.title
        ) else {
            displayToast(message: "Tab no longer exists (may have been closed)")
            return
        }

        do {
            try await ChromeController.shared.activateTab(
                windowId: tab.windowId,
                tabIndex: currentIndex
            )
            displayToast(message: "Switched to tab: \(tab.title.prefix(40))")
        } catch {
            displayToast(message: "Failed to activate tab: \(error.localizedDescription)")
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
