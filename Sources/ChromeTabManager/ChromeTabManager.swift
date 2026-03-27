import SwiftUI
import AppKit

@main
struct ChromeTabManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Use Window (not WindowGroup) for single-window utility app
        // Prevents duplicate command handling across multiple windows
        Window("TabPilot", id: "main") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Tabs") {
                Button("Scan Tabs") {
                    NotificationCenter.default.post(name: .scanTabs, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityLabel("Scan Chrome tabs")
                .accessibilityHint("Scans all open Chrome windows for duplicate tabs")
                
                Button("Refresh Tabs") {
                    NotificationCenter.default.post(name: .refreshTabs, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .accessibilityLabel("Refresh tab list")
                .accessibilityHint("Quick refresh that detects tab changes without full rescan")
                
                Divider()
                
                Button("Review Cleanup Plan") {
                    NotificationCenter.default.post(name: .reviewPlan, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .accessibilityLabel("Review cleanup plan")
                .accessibilityHint("Opens a review sheet showing which tabs will be closed")
                
                Divider()
                
                Button("Smart Select") {
                    NotificationCenter.default.post(name: .smartSelect, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .accessibilityLabel("Smart select tabs")
                .accessibilityHint("Selects tabs based on smart selection strategy")
                
                Button("Select All") {
                    NotificationCenter.default.post(name: .selectAllTabs, object: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
                .accessibilityLabel("Select all tabs")
                .accessibilityHint("Selects all visible tabs in the current view")
                
                Button("Deselect All") {
                    NotificationCenter.default.post(name: .deselectAllTabs, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .accessibilityLabel("Deselect all tabs")
                .accessibilityHint("Clears all current tab selections")
                
                Divider()
                
                Button("Close Selected") {
                    NotificationCenter.default.post(name: .closeSelected, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
                .accessibilityLabel("Close selected tabs")
                .accessibilityHint("Closes all selected tabs. 30-second undo available.")
                
                Button("Undo Last Close") {
                    NotificationCenter.default.post(name: .undoLastClose, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("Undo last close")
                .accessibilityHint("Restores tabs closed in the last 30 seconds")
                
                Button("Redo") {
                    NotificationCenter.default.post(name: .redoAction, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityLabel("Redo action")
                .accessibilityHint("Re-applies the last undone action")
                
                Divider()
                
                Button("Focus Filter") {
                    NotificationCenter.default.post(name: .focusFilter, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                .accessibilityLabel("Focus filter field")
                .accessibilityHint("Moves keyboard focus to the filter/search field")
                
                Button("Clear Filter") {
                    NotificationCenter.default.post(name: .clearFilter, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Clear filter")
                .accessibilityHint("Clears the current filter and shows all tabs")
            }
            
            CommandGroup(after: .appSettings) {
                Button("Preferences...") {
                    NotificationCenter.default.post(name: .showPreferences, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel("Open preferences")
                .accessibilityHint("Opens the application preferences window")
                
                Button("Install Chrome Extension...") {
                    NotificationCenter.default.post(name: .showExtensionGuide, object: nil)
                }
                .accessibilityLabel("Install Chrome extension")
                .accessibilityHint("Shows instructions for installing the Chrome extension")
                
                Divider()
                
                Button("Show Archive History") {
                    NotificationCenter.default.post(name: .showArchiveHistory, object: nil)
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])
                .accessibilityLabel("Show archive history")
                .accessibilityHint("Opens the archive history view")
            }
            
            // Remove New Window command since we're single-window
            CommandGroup(replacing: .newItem) {}
            
            // Add help command
            CommandGroup(after: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcutsHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
                .accessibilityLabel("Show keyboard shortcuts")
                .accessibilityHint("Displays a help sheet with all available keyboard shortcuts")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let securityReport = RuntimeProtection.evaluate()
        RuntimeProtection.applyMitigations(for: securityReport)
        Task {
            await SecurityAuditLogger.shared.logRuntimeReport(securityReport)
            await SecurityAuditLogger.shared.log(
                category: "application",
                action: "launch_completed",
                severity: .info
            )
        }

        // Ensure window is visible but don't force activation over other apps
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        
        // Register global hotkeys (Cmd+Shift+C to scan, Cmd+Shift+D to close duplicates)
        HotkeyManager.shared.enable()
        
        // Request notification permissions if user has enabled time notifications
        if TabTimeNotificationManager.shared.isEnabled {
            TabTimeNotificationManager.shared.requestAuthorization()
        }
        
        // Post accessibility announcement that app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AccessibilityAnnouncements.announce("TabPilot is ready")
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let scanTabs = Notification.Name("scanTabs")
    static let refreshTabs = Notification.Name("refreshTabs")
    static let smartSelect = Notification.Name("smartSelect")
    static let closeSelected = Notification.Name("closeSelected")
    static let showPreferences = Notification.Name("showPreferences")
    static let reviewPlan = Notification.Name("reviewPlan")
    static let focusFilter = Notification.Name("focusFilter")
    static let clearFilter = Notification.Name("clearFilter")
    static let showExtensionGuide = Notification.Name("showExtensionGuide")
    static let selectAllTabs = Notification.Name("selectAllTabs")
    static let deselectAllTabs = Notification.Name("deselectAllTabs")
    static let undoLastClose = Notification.Name("undoLastClose")
    static let redoAction = Notification.Name("redoAction")
    static let showArchiveHistory = Notification.Name("showArchiveHistory")
    static let showKeyboardShortcutsHelp = Notification.Name("showKeyboardShortcutsHelp")
}
