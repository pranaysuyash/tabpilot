import SwiftUI
import Combine
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Typealiases for backwards compatibility with Views
    typealias DuplicateViewMode = ChromeTabManager.DuplicateViewMode
    typealias ExportFormat = ChromeTabManager.ExportFormat
    
    // MARK: - Feature Controllers
    let scanController: ScanController
    let tabSelectionController: TabSelectionController
    let undoController: UndoController
    let licenseController: LicenseController
    
    // MARK: - UI State
    var toastMessage: String?
    var showToast = false
    var showPaywall = false
    var showPreferences = false
    var isPreferencesOpen = false
    var showReviewPlan = false
    var showArchiveHistory = false
    var showConfirmation = false
    var confirmationTitle = ""
    var confirmationMessage = ""
    
    // MARK: - Import/Export
    var importPreviewTabs: [ImportTab] = []
    var isImportResultPresented = false
    var exportFormat: ExportFormat = .json
    
    // MARK: - Protected Domains
    var protectedDomains: [String] = ["mail.google.com", "calendar.google.com"]
    var newProtectedDomain: String = ""
    
    // MARK: - Recent Archives
    var recentArchives: [URL] = []
    
    // MARK: - URL Patterns
    var urlPatterns: [URLPattern] = []
    
    // MARK: - Sessions
    var sessions: [Session] = []
    
    // MARK: - Cleanup Rules
    var cleanupRules: [CleanupRule] = []
    
    // MARK: - Review Plan
    var reviewPlanItems: [ReviewPlanItem] = []
    var reviewPlanKeepPolicy = ""
    
    // MARK: - Closed Tab History
    var closedTabHistory: ClosedTabHistoryStore?

    // MARK: - Private State
    private var confirmationAction: (() async -> Void)?
    private let closeUseCase: CloseTabsUseCaseProtocol
    private let exportUseCase: ExportTabsUseCaseProtocol
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties (delegated to controllers)
    var tabs: [TabInfo] { scanController.tabs }
    var windows: [WindowInfo] { scanController.windows }
    var duplicateGroups: [DuplicateGroup] { scanController.duplicateGroups }
    var isScanning: Bool { scanController.isScanning }
    var scanProgress: Double { scanController.scanProgress }
    var scanMessage: String { scanController.scanMessage }
    var scanStats: ScanTelemetry? { scanController.scanStats }
    var instances: [ChromeInstance] { scanController.instances }
    var userAnalysis: UserAnalysis? { scanController.userAnalysis }
    var errorMessage: String? {
        get { scanController.errorMessage }
        set { scanController.errorMessage = newValue }
    }
    
    var selectedTabIds: Set<String> {
        get { tabSelectionController.selectedTabIds }
        set { tabSelectionController.selectedTabIds = newValue }
    }
    var searchQuery: String {
        get { tabSelectionController.searchQuery }
        set { tabSelectionController.searchQuery = newValue }
    }
    var debouncedSearchQuery: String { tabSelectionController.debouncedSearchQuery }
    var viewMode: DuplicateViewMode {
        get { tabSelectionController.viewMode }
        set { tabSelectionController.viewMode = newValue }
    }
    var filteredDuplicates: [DuplicateGroup] { tabSelectionController.filteredDuplicates }
    
    var canUndo: Bool { undoController.canUndo }
    var undoMessage: String { undoController.undoMessage }
    var undoTimeRemaining: Double { undoController.undoTimeRemaining }
    
    var isLicensed: Bool { licenseController.isLicensed }
    
    var licenseManager: LicenseManager { LicenseManager.shared }
    
    // MARK: - More Computed
    var hasDuplicates: Bool { scanController.hasDuplicates }
    var config: PersonaConfig { scanController.config }
    var healthMetrics: HealthMetrics? { scanController.healthMetrics }
    var domainGroups: [DomainGroup] { scanController.domainGroups }
    var pruningCandidates: [TabInfo] { scanController.pruningCandidates }
    
    // MARK: - Preferences
    var defaultExportFormat: ExportFormat {
        get {
            let raw = UserDefaults.standard.string(forKey: DefaultsKeys.defaultExportFormat) ?? ExportFormat.json.rawValue
            return ExportFormat(rawValue: raw) ?? .json
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKeys.defaultExportFormat)
        }
    }
    
    var archiveLocationPath: String {
        get { UserDefaults.standard.string(forKey: DefaultsKeys.archiveLocationPath) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKeys.archiveLocationPath) }
    }
    
    var defaultKeepPolicy: String {
        get { UserDefaults.standard.string(forKey: "defaultKeepPolicy") ?? "first" }
        set { UserDefaults.standard.set(newValue, forKey: "defaultKeepPolicy") }
    }
    
    var confirmDestructive: Bool {
        get { UserDefaults.standard.bool(forKey: "confirmDestructive") }
        set { UserDefaults.standard.set(newValue, forKey: "confirmDestructive") }
    }
    
    var ignoreTrackingParams: Bool {
        get { UserDefaults.standard.bool(forKey: "ignoreTrackingParams") }
        set {
            UserDefaults.standard.set(newValue, forKey: "ignoreTrackingParams")
            tabSelectionController.invalidateDuplicateCache()
        }
    }
    
    var stripQueryParams: Bool {
        get { UserDefaults.standard.bool(forKey: "stripQueryParams") }
        set {
            UserDefaults.standard.set(newValue, forKey: "stripQueryParams")
            tabSelectionController.invalidateDuplicateCache()
        }
    }
    
    var maxDuplicatesDisplay: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "maxDuplicatesDisplay")
            return val > 0 ? val : 100
        }
        set { UserDefaults.standard.set(newValue, forKey: "maxDuplicatesDisplay") }
    }

    // MARK: - Initialization
    init() {
        self.scanController = ScanController()
        self.tabSelectionController = TabSelectionController()
        self.undoController = UndoController()
        self.licenseController = LicenseController()
        self.closeUseCase = DefaultCloseTabsUseCase()
        self.exportUseCase = DefaultExportTabsUseCase()
        self.eventBus = .shared
        
        setupNotifications()
        loadRecentArchives()
        loadProtectedDomains()
        Task { @MainActor in AutoCleanupManager.shared.setup() }
    }
    
    // Call this after init to wire up cross-controller access
    func wireUpControllers() {
        tabSelectionController.duplicateGroupsProvider = { [weak self] in
            self?.scanController.duplicateGroups ?? []
        }
    }
    
    // MARK: - Setup
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
                Task { await self?.requestCloseSelected() }
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
                Task { await self?.requestCloseAllDuplicates(keepOldest: true) }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .closeDuplicates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.closeAllDuplicatesDirectly() }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Domain Protection
    private func loadProtectedDomains() {
        if let saved = UserDefaults.standard.stringArray(forKey: "protectedDomains") {
            protectedDomains = saved
        }
    }
    
    func addProtectedDomain() {
        let trimmed = newProtectedDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty && !protectedDomains.contains(trimmed) else { return }
        protectedDomains.append(trimmed)
        UserDefaults.standard.set(protectedDomains, forKey: "protectedDomains")
        newProtectedDomain = ""
        Task { await scan() }
    }
    
    func removeProtectedDomain(_ domain: String) {
        protectedDomains.removeAll { $0 == domain }
        UserDefaults.standard.set(protectedDomains, forKey: "protectedDomains")
        Task { await scan() }
    }
    
    func isDomainProtected(_ url: String) -> Bool {
        scanController.isDomainProtected(url)
    }
    
    // MARK: - Scan Actions
    func scan() async {
        await scanController.scan()
    }
    
    func incrementalScan() async {
        await scanController.incrementalScan()
    }
    
    // MARK: - Selection Actions
    func smartSelect() {
        tabSelectionController.smartSelect()
    }
    
    func selectAll() {
        tabSelectionController.selectAll()
    }
    
    func selectDuplicates() {
        tabSelectionController.selectDuplicates()
    }
    
    func deselectAll() {
        tabSelectionController.deselectAll()
    }
    
    func toggleSelection(for tabId: String) {
        tabSelectionController.toggleSelection(for: tabId)
    }
    
    func selectAll(in group: DuplicateGroup) {
        tabSelectionController.selectAll(in: group)
    }
    
    func selectAllExceptOldest(in group: DuplicateGroup) {
        tabSelectionController.selectAllExceptOldest(in: group)
    }
    
    func selectAllExceptNewest(in group: DuplicateGroup) {
        tabSelectionController.selectAllExceptNewest(in: group)
    }
    
    // MARK: - Close Actions
    func requestCloseSelected() {
        let toClose = tabs.filter { selectedTabIds.contains($0.id) }
        guard !toClose.isEmpty else { return }
        guard ensureCanClose(requestedCount: toClose.count) else { return }
        
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
    
    func closeSelectedTabs() async {
        let toClose = tabs.filter { selectedTabIds.contains($0.id) }
        guard !toClose.isEmpty else { return }
        
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            ErrorPresenter.shared.present(userError)
            return
        }
        
        undoController.startUndoTimer(with: toClose)
        
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
        
        if totalAmbiguous > 0 {
            displayToast(message: "Closed \(totalClosed), \(totalAmbiguous) ambiguous (skipped)")
        } else if totalFailed > 0 {
            displayToast(message: "Closed \(totalClosed), failed \(totalFailed)")
        }
        
        selectedTabIds.removeAll()
        await scan()
    }
    
    // MARK: - Review Plan
    func requestCloseAllDuplicates(keepOldest: Bool = true) {
        let totalToClose = duplicateGroups.reduce(0) { $0 + $1.wastedCount }
        guard totalToClose > 0 else { return }
        guard ensureCanClose(requestedCount: totalToClose) else { return }
        
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
        
        undoController.startUndoTimer(with: tabsToClose)
        
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
    
    // MARK: - Confirmation
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
    
    // MARK: - Undo
    func undoLastClose() async {
        let restoredCount = await undoController.performUndo()
        displayToast(message: "Restored \(restoredCount) tabs")
        await scan()
    }
    
    func dismissUndo() {
        undoController.dismissUndo()
    }
    
    // MARK: - Tab Operations
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
    
    func activateTab(_ tab: TabInfo) async {
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            ErrorPresenter.shared.present(userError)
            return
        }
        
        guard let currentIndex = await ChromeController.shared.findTabIndex(
            windowId: tab.windowId,
            url: tab.url,
            title: tab.title
        ) else {
            let userError = UserFacingError.tabNotFound
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
            ErrorPresenter.shared.present(userError)
        }
    }
    
    // MARK: - Close All Duplicates
    func closeAllDuplicates(keepOldest: Bool = true) async {
        let requested = duplicateGroups.reduce(0) { $0 + $1.wastedCount }
        guard ensureCanClose(requestedCount: requested) else { return }
        
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
            ErrorPresenter.shared.present(userError)
            return
        }
        
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

        let windowResults = await withTaskGroup(of: (closed: Int, failed: Int, ambiguous: Int).self) { group in
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
    
    func closeAllDuplicatesDirectly() async {
        await closeAllDuplicates(keepOldest: true)
    }
    
    // MARK: - Toast
    func displayToast(message: String) {
        toastMessage = message
        showToast = true
        
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            await MainActor.run {
                self.showToast = false
            }
        }
    }
    
    // MARK: - Archive
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
            ErrorPresenter.shared.present(userError)
        }
    }
    
    func archiveSelectedTabs(fileName: String?, format: ExportFormat, append: Bool) {
        let selected = tabs.filter { selectedTabIds.contains($0.id) }
        Task { await archiveTabs(selected, fileName: fileName, format: format, append: append) }
    }
    
    // MARK: - Export
    
    func exportContent(for tabs: [TabInfo], format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return ExportManager.export(tabs: tabs, format: .markdown)
        case .html:
            return bookmarksHTML(for: tabs, title: "TabPilot Export")
        case .json:
            return tabsJSON(for: tabs)
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
            Task {
                await self?.exportTabs(selected, format: format, to: url)
            }
        }
    }
    
    func exportTabs(_ tabs: [TabInfo], format: ExportFormat, to url: URL) async {
        do {
            let content = exportContent(for: tabs, format: format)
            try content.write(to: url, atomically: true, encoding: .utf8)
            displayToast(message: "Exported \(tabs.count) tabs")
        } catch {
            let userError = UserFacingError.scanFailed(reason: "Export failed: \(error.localizedDescription)")
            ErrorPresenter.shared.present(userError)
        }
    }
    
    // MARK: - Import
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
            ErrorPresenter.shared.present(userError)
            return []
        }
    }
    
    func openImportedTabs(_ importedTabs: [ImportTab]) async {
        guard !importedTabs.isEmpty else { return }
        guard await ChromeController.shared.isChromeRunning() else {
            let userError = UserFacingError.chromeNotRunning
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
    
    // MARK: - Move Tabs
    func moveTabsToWindow(tabIds: [String], targetWindowId: Int) async {
        guard await ChromeController.shared.isChromeRunning() else { return }
        
        let tabsToMove = tabs.filter { tabIds.contains($0.id) }
        guard !tabsToMove.isEmpty else { return }
        
        let bySourceWindow = Dictionary(grouping: tabsToMove) { $0.windowId }
        
        var opened = 0
        for tab in tabsToMove {
            let success = await ChromeController.shared.openTab(windowId: targetWindowId, url: tab.url)
            if success { opened += 1 }
        }
        
        for (sourceWindowId, windowTabs) in bySourceWindow where sourceWindowId != targetWindowId {
            let targets = windowTabs.map { (url: $0.url, title: $0.title) }
            _ = await closeUseCase.execute(windowId: sourceWindowId, targets: targets)
        }
        
        if opened > 0 {
            displayToast(message: "Moved \(opened) tabs to window \(targetWindowId)")
        }
        await scan()
    }
    
    func moveTabsToNewWindow(tabIds: [String]) async {
        guard await ChromeController.shared.isChromeRunning() else { return }
        
        let tabsToMove = tabs.filter { tabIds.contains($0.id) }
        guard !tabsToMove.isEmpty else { return }
        
        let sourceIds = Set(tabsToMove.map { $0.windowId })
        guard let targetWindowId = windows.first(where: { !sourceIds.contains($0.windowId) })?.windowId else {
            displayToast(message: "No other window to move tabs to")
            return
        }
        await moveTabsToWindow(tabIds: tabIds, targetWindowId: targetWindowId)
    }
    
    // MARK: - Review Plan Item
    struct ReviewPlanItem: Identifiable {
        let id = UUID()
        let group: DuplicateGroup
        let keepTab: TabInfo
        let closeTabs: [TabInfo]
        var isIncluded: Bool = true
    }
    
    // MARK: - Archive Helpers
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
    
    // MARK: - Export Helpers
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
            app: "TabPilot"
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
    
    // MARK: - Private Helpers
    private func ensureCanClose(requestedCount: Int) -> Bool {
        guard requestedCount > 0 else { return true }
        if !isLicensed {
            showPaywall = true
            displayToast(message: "Please unlock TabPilot to close tabs.")
            return false
        }
        return true
    }
    
    private func closeConfirmationMessage(for count: Int) -> String {
        return "This will close \(count) selected tabs. You can undo this action for 30 seconds."
    }
}
