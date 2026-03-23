import SwiftUI

struct AppToolbarContent: ToolbarContent {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some SwiftUI.ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let analysis = viewModel.userAnalysis, analysis.persona != .light {
                // View mode buttons
                ForEach(TabManagerViewModel.DuplicateViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.viewMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                    .keyboardShortcut(viewModeShortcut(for: mode), modifiers: .command)
                }
                
                Button(action: { Task { await viewModel.scan() } }) {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

func viewModeShortcut(for mode: TabManagerViewModel.DuplicateViewMode) -> KeyEquivalent {
    switch mode {
    case .overall: return "1"
    case .byWindow: return "2"
    case .byDomain: return "3"
    case .crossWindow: return "4"
    }
}
