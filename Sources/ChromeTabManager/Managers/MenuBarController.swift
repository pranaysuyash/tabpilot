import Foundation
import AppKit

/// Controls the macOS menu bar status item for the app.
/// Shows at-a-glance tab count and provides quick scan action.
@MainActor
class MenuBarController: ObservableObject {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var tabCount: Int = 0
    private var duplicateCount: Int = 0
    
    private init() {}
    
    // MARK: - Public API
    
    func show() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateDisplay()
        setupMenu()
    }
    
    func hide() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }
    
    func update(tabCount: Int, duplicateCount: Int) {
        self.tabCount = tabCount
        self.duplicateCount = duplicateCount
        updateDisplay()
    }
    
    // MARK: - Private
    
    private func updateDisplay() {
        guard let button = statusItem?.button else { return }
        
        if duplicateCount > 0 {
            button.image = NSImage(systemSymbolName: "doc.on.doc.fill", accessibilityDescription: "TabPilot")
            button.title = " \(duplicateCount)"
            button.imagePosition = .imageLeft
        } else {
            button.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "TabPilot")
            button.title = ""
        }
        
        button.toolTip = "\(tabCount) tabs · \(duplicateCount) duplicates"
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let scanItem = NSMenuItem(title: "Scan Tabs", action: #selector(scanTabs), keyEquivalent: "")
        scanItem.target = self
        menu.addItem(scanItem)
        
        menu.addItem(.separator())
        
        let openItem = NSMenuItem(title: "Open TabPilot", action: #selector(openApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func scanTabs() {
        NotificationCenter.default.post(name: .scanTabs, object: nil)
        openApp()
    }
    
    @objc private func openApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
