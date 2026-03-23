import SwiftUI
import AppKit

@main
struct ChromeTabManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Use Window (not WindowGroup) for single-window utility app
        // Prevents duplicate command handling across multiple windows
        Window("Chrome Tab Manager", id: "main") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Tabs") {
                Button("Scan Tabs") {
                    NotificationCenter.default.post(name: .scanTabs, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Review Cleanup Plan") {
                    NotificationCenter.default.post(name: .reviewPlan, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Smart Select") {
                    NotificationCenter.default.post(name: .smartSelect, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Close Selected") {
                    NotificationCenter.default.post(name: .closeSelected, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
                
                Divider()
                
                Button("Focus Filter") {
                    NotificationCenter.default.post(name: .focusFilter, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            
            CommandGroup(after: .appSettings) {
                Button("Preferences...") {
                    NotificationCenter.default.post(name: .showPreferences, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Remove New Window command since we're single-window
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure window is visible and activated
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
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

extension Notification.Name {
    static let scanTabs = Notification.Name("scanTabs")
    static let smartSelect = Notification.Name("smartSelect")
    static let closeSelected = Notification.Name("closeSelected")
    static let showPreferences = Notification.Name("showPreferences")
    static let reviewPlan = Notification.Name("reviewPlan")
    static let focusFilter = Notification.Name("focusFilter")
}
