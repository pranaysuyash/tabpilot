import Foundation

/// Manages automatic cleanup of tabs based on rules.
/// Runs cleanup checks on a timer to automatically close tabs matching rules.
@MainActor
class AutoCleanupManager: ObservableObject {
    static let shared = AutoCleanupManager()
    
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.autoCleanupEnabled)
            updateTimer()
        }
    }
    
    @Published var checkInterval: TimeInterval = 15 * 60 {
        didSet {
            UserDefaults.standard.set(checkInterval, forKey: DefaultsKeys.autoCleanupInterval)
            updateTimer()
        }
    }
    
    @Published var lastCheckAt: Date?
    @Published var nextCheckAt: Date?
    @Published var lastCleanedCount: Int = 0
    
    private var timer: Timer?
    private var cleanupRules: [CleanupRule] = []
    
    private init() {
        loadSettings()
    }
    
    func setup() {
        loadRules()
        updateTimer()
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: DefaultsKeys.autoCleanupEnabled)
        checkInterval = UserDefaults.standard.object(forKey: DefaultsKeys.autoCleanupInterval) as? TimeInterval ?? 15 * 60
    }
    
    private func loadRules() {
        cleanupRules = CleanupRuleStore.shared.rules
    }
    
    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        nextCheckAt = nil
        
        guard isEnabled, cleanupRules.contains(where: { $0.enabled }) else { return }
        
        nextCheckAt = Date().addingTimeInterval(checkInterval)
        
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanupCheck()
            }
        }
    }
    
    func refreshRules() {
        loadRules()
        updateTimer()
    }
    
    func performCleanupCheck() async {
        guard isEnabled else { return }
        
        loadRules()
        
        let enabledRules = cleanupRules.filter { $0.enabled }
        guard !enabledRules.isEmpty else { return }
        
        lastCheckAt = Date()
        nextCheckAt = Date().addingTimeInterval(checkInterval)
        
        do {
            let result = try await ChromeController.shared.scanAllTabsFast { _, _ in }
            let tabs = result.tabs
            
            var tabsToClose: [TabInfo] = []
            
            for tab in tabs {
                for rule in enabledRules {
                    if rule.matches(tab) {
                        tabsToClose.append(tab)
                        break
                    }
                }
            }
            
            guard !tabsToClose.isEmpty else { return }
            
            // Save snapshot for undo
            SnapshotManager.shared.saveSnapshot(tabs: tabsToClose, label: "auto-cleanup")
            
            // Archive before closing
            AutoArchiveManager.shared.archiveClosedTabs(tabsToClose)
            
            // Perform cleanup
            for tab in tabsToClose {
                try? await ChromeController.shared.closeTab(
                    windowId: tab.windowId,
                    tabIndex: tab.tabIndex
                )
            }
            
            lastCleanedCount = tabsToClose.count
            
        } catch {
            SecureLogger.error("Auto-cleanup check failed: \(error.localizedDescription)")
        }
    }
    
    func addRule(_ rule: CleanupRule) {
        CleanupRuleStore.shared.add(rule)
        refreshRules()
    }
    
    func removeRule(_ rule: CleanupRule) {
        CleanupRuleStore.shared.delete(rule)
        refreshRules()
    }
    
    func updateRule(_ rule: CleanupRule) {
        CleanupRuleStore.shared.update(rule)
        refreshRules()
    }

    func previewRule(_ rule: CleanupRule, against tabs: [TabInfo]) -> [TabInfo] {
        tabs.filter { rule.matches($0) }
    }
}
