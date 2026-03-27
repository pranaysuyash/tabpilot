import Foundation
import AppKit

@MainActor
@Observable
final class UndoController {
    // MARK: - Constants
    static let undoTimeout: TimeInterval = 30
    
    // MARK: - State
    private(set) var canUndo = false
    private(set) var undoMessage = ""
    private(set) var undoTimeRemaining: TimeInterval = 0
    
    var undoTimeRemainingFormatted: String {
        guard canUndo else { return "" }
        return "\(Int(undoTimeRemaining))s"
    }
    
    private(set) var lastClosedTabs: [ClosedTabRecord] = []
    
    // MARK: - Timers
    private var undoTimer: Timer?
    private var undoCountdownTimer: Timer?
    
    // MARK: - Dependencies
    private let eventBus: EventBus
    
    // MARK: - Initialization
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
    }
    
    // MARK: - Public Methods
    
    func startUndoTimer(with tabs: [TabInfo]) {
        guard LicenseManager.shared.isLicensed else {
            clearUndo()
            return
        }
        
        lastClosedTabs = tabs.map { tab in
            ClosedTabRecord(
                windowId: tab.windowId,
                url: tab.url,
                title: tab.title,
                closedAt: Date()
            )
        }
        
        eventBus.publish(ArchiveCreatedEvent(archiveId: UUID().uuidString, tabCount: tabs.count))
        
        canUndo = true
        undoMessage = "Closed \(tabs.count) tabs"
        undoTimeRemaining = Self.undoTimeout
        
        startCountdownTimer()
        scheduleUndoExpiration()
    }
    
    func cancelUndo() {
        clearUndo()
    }
    
    func dismissUndo() {
        clearUndo()
    }
    
    func performUndo() async -> Int {
        guard LicenseManager.shared.isLicensed else { return 0 }
        guard !lastClosedTabs.isEmpty else { return 0 }
        
        // Batch open all tabs via single AppleScript call per window for better performance.
        // Opening 100+ tabs sequentially with 100ms delay each would take 10+ seconds.
        
        let tabsByWindow = Dictionary(grouping: lastClosedTabs) { $0.windowId }
        
        var restoredCount = 0
        var failedCount = 0
        
        for (windowId, tabs) in tabsByWindow {
            let urls = tabs.map { $0.url }
            let escapedUrls = urls.map { appleScriptEscape($0) }
            let urlList = escapedUrls.map { "\"\($0)\"" }.joined(separator: ", ")
            
            let script = """
            tell application "Google Chrome"
                tell window \(windowId)
                    repeat with theURL in {\(urlList)}
                        set newTab to make new tab
                        set URL of newTab to theURL
                    end repeat
                end tell
                return "done"
            end tell
            """
            
            do {
                let result = try await ChromeController.shared.runAppleScript(script, timeout: 30)
                if result.trimmingCharacters(in: .whitespacesAndNewlines) == "done" {
                    restoredCount += tabs.count
                } else {
                    failedCount += tabs.count
                }
            } catch {
                SecureLogger.error("Batch undo failed for window \(windowId): \(error)")
                failedCount += tabs.count
            }
        }
        
        if failedCount > 0 {
            SecureLogger.info("Undo: Restored \(restoredCount) tabs, failed \(failedCount)")
        } else {
            SecureLogger.info("Undo: Successfully restored \(restoredCount) tabs")
        }
        
        clearUndo()
        return restoredCount
    }
    
    // MARK: - Private Methods
    
    private func startCountdownTimer() {
        undoCountdownTimer?.invalidate()
        undoCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func scheduleUndoExpiration() {
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: Self.undoTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearUndo()
            }
        }
    }
    
    private func tick() {
        guard canUndo else { return }
        
        undoTimeRemaining -= 1
        
        if undoTimeRemaining <= 0 {
            undoTimeRemaining = 0
            clearUndo()
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
}
