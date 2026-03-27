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
        guard !lastClosedTabs.isEmpty else { return 0 }
        
        var restoredCount = 0
        var failedCount = 0
        
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
