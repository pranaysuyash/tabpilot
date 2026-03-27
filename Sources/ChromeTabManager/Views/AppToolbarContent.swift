import SwiftUI

struct AppToolbarContent: ToolbarContent {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some SwiftUI.ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let analysis = viewModel.userAnalysis, analysis.persona != .light {
                // View mode buttons
                ForEach(DuplicateViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.viewMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                    .keyboardShortcut(viewModeShortcut(for: mode), modifiers: .command)
                    .accessibilityLabel("View mode: \(mode.rawValue)")
                    .accessibilityHint(mode.description)
                    .accessibilityValue(viewModel.viewMode == mode ? "selected" : "not selected")
                }
                
                Button(action: { Task { await viewModel.scan() } }) {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityLabel("Scan Chrome tabs")
                .accessibilityHint("Triggers a full scan of all open Chrome windows")
                
                if !viewModel.tabs.isEmpty {
                    Button(action: { Task { await viewModel.incrementalScan() } }) {
                        Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.isScanning)
                    .help("Quick refresh - detects changes without full rescan")
                    .accessibilityLabel("Refresh tab list")
                    .accessibilityHint("Quick refresh that detects tab changes without a full rescan")
                }
            }
        }
    }
}

func viewModeShortcut(for mode: DuplicateViewMode) -> KeyEquivalent {
    switch mode {
    case .overall: return "1"
    case .byWindow: return "2"
    case .byDomain: return "3"
    case .crossWindow: return "4"
    }
}
