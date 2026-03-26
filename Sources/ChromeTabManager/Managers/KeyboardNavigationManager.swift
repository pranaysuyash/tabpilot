import SwiftUI
import Combine

/// Manages keyboard focus and navigation throughout the app
@MainActor
final class KeyboardNavigationManager: ObservableObject {
    static let shared = KeyboardNavigationManager()
    
    @Published var currentFocus: NavigationFocus = .none
    @Published var selectedGroupIndex: Int = 0
    
    enum NavigationFocus: String, CaseIterable {
        case none, sidebar, toolbar, list, table, reviewPlan
    }
    
    private init() {}
    
    func moveFocus(to focus: NavigationFocus) {
        currentFocus = focus
        let message: String
        switch focus {
        case .sidebar: message = "Sidebar"
        case .toolbar: message = "Toolbar"
        case .list: message = "Duplicate list"
        case .table: message = "Table view"
        case .reviewPlan: message = "Review plan"
        case .none: return
        }
        AccessibilityNotification.announcement.post(argument: message)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
    static let toggleTableView = Notification.Name("toggleTableView")
}

// MARK: - Accessibility Utilities

enum AccessibilityNotification {
    case announcement, layoutChanged, screenChanged
    
    @MainActor
    func post(argument: Any?) {
        let notification: NSAccessibility.Notification
        switch self {
        case .announcement: notification = .announcementRequested
        case .layoutChanged: notification = .layoutChanged
        case .screenChanged: notification = .mainWindowChanged
        }
        
        if let argument = argument {
            NSAccessibility.post(element: NSApp as Any, notification: notification, userInfo: [.announcement: argument])
        } else {
            NSAccessibility.post(element: NSApp as Any, notification: notification)
        }
    }
}

// MARK: - Keyboard Shortcuts Help View

struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    let shortcuts: [(key: String, description: String, category: String)] = [
        ("Tab", "Move focus to next section", "Navigation"),
        ("Shift + Tab", "Move focus to previous section", "Navigation"),
        ("↑ / ↓", "Navigate items in current list", "Navigation"),
        ("Home", "Jump to first item", "Navigation"),
        ("End", "Jump to last item", "Navigation"),
        ("Space", "Select/deselect current item", "Actions"),
        ("Return", "Activate current item (focus tab)", "Actions"),
        ("⌘ + Return", "Close current duplicate group", "Actions"),
        ("⌘ + Delete", "Close selected tabs", "Actions"),
        ("⌘ + R", "Scan Chrome tabs", "Commands"),
        ("⌘ + F", "Focus filter/search field", "Commands"),
        ("⌘ + Shift + P", "Review cleanup plan", "Commands"),
        ("⌘ + Shift + S", "Smart select tabs", "Commands"),
        ("⌘ + ,", "Open preferences", "Commands"),
        ("⌘ + ?", "Show keyboard shortcuts", "Commands"),
        ("⌘ + T", "Toggle table/list view", "View"),
        ("⌘ + Shift + C", "Scan tabs (global)", "Global"),
        ("⌘ + Shift + D", "Close duplicates (global)", "Global"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    let categories = Dictionary(grouping: shortcuts, by: { $0.category })
                    ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category).font(.headline)
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(categories[category]!, id: \.key) { shortcut in
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(shortcut.key)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.semibold)
                                            .frame(width: 140, alignment: .trailing)
                                        Text(shortcut.description)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                        if category != categories.keys.sorted().last {
                            Divider().padding(.vertical, 8)
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                Text("Press ⌘ + ? anytime to show this help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 600, height: 700)
    }
}
