import AppKit

/// Registers global keyboard shortcuts that work even when the app is backgrounded.
/// Uses NSEvent.addGlobalMonitorForEvents — requires Accessibility permission.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var monitors: [Any] = []
    private var isEnabled = false

    private init() {}

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true

        // Global monitors fire when OTHER apps are frontmost.
        // Local monitors (addLocalMonitorForEvents) fire when our app is frontmost.
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.shouldCapture(event) == true {
                Task { @MainActor in self?.handle(event) }
                return nil // consume event
            }
            return event
        }
        if let g = globalMonitor { monitors.append(g) }
        if let l = localMonitor { monitors.append(l) }
    }

    func disable() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        isEnabled = false
    }

    // MARK: - Private

    private func shouldCapture(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return mods == [.command, .shift] && (event.keyCode == kVK_c || event.keyCode == kVK_d)
    }

    private func handle(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods == [.command, .shift] else { return }

        switch event.keyCode {
        case kVK_c:
            // Cmd+Shift+C → bring app to front and trigger scan
            bringToFront()
            NotificationCenter.default.post(name: .scanTabs, object: nil)
        case kVK_d:
            // Cmd+Shift+D → bring app to front and close duplicates
            bringToFront()
            NotificationCenter.default.post(name: .closeDuplicates, object: nil)
        default:
            break
        }
    }

    private func bringToFront() {
        NSApplication.shared.activate()
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
    }
}

// Virtual keycodes (Carbon HIToolbox — always available on macOS)
private let kVK_c: UInt16 = 0x08
private let kVK_d: UInt16 = 0x02

extension Notification.Name {
    static let closeDuplicates = Notification.Name("closeDuplicates")
}
