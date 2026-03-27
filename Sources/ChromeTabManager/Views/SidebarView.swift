import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        List {
            if let analysis = viewModel.userAnalysis {
                PersonaCard(analysis: analysis, viewModel: viewModel)
            } else if viewModel.isScanning {
                ScanningCard(viewModel: viewModel)
            } else {
                WelcomeCard()
            }
            
            if let analysis = viewModel.userAnalysis, analysis.persona != .light {
                if viewModel.config.showWindowBreakdown {
                    Section("Windows") {
                        ForEach(viewModel.windows) { window in
                            WindowRow(window: window)
                        }
                    }
                    .accessibilityLabel("Windows section")
                }
                
                Section("Tab Health") {
                    TabDebtView(viewModel: viewModel)
                        .padding(.vertical, 4)
                }
                .accessibilityLabel("Tab Health section")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(sidebarTitle)
    }
    
    private var sidebarTitle: String {
        if viewModel.isScanning {
            return "Scanning"
        }
        
        if viewModel.userAnalysis != nil {
            switch viewModel.viewMode {
            case .overall:
                return "Duplicates"
            case .byWindow:
                return "By Window"
            case .byDomain:
                return "By Domain"
            case .crossWindow:
                return "Cross-Window"
            }
        }
        
        return "TabPilot"
    }
}

struct PersonaCard: View {
    let analysis: UserAnalysis
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(analysis.icon)
                        .font(.system(size: 40))
                        .accessibilityLabel("Persona icon: \(analysis.icon)")
                    
                    VStack(alignment: .leading) {
                        Text(analysis.title)
                            .font(.headline)
                            .accessibilityLabel("Persona: \(analysis.title)")
                        
                        Text(analysis.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .accessibilityLabel(analysis.description)
                    }
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatBadge(value: analysis.totalTabs, label: "Tabs", color: Color.blue)
                        .accessibilityLabel("\(analysis.totalTabs) total tabs")
                    
                    StatBadge(value: analysis.windowCount, label: "Windows", color: .purple)
                        .accessibilityLabel("\(analysis.windowCount) Chrome windows")
                    
                    StatBadge(value: analysis.duplicateGroups, label: "Duplicates", color: .orange)
                        .accessibilityLabel("\(analysis.duplicateGroups) duplicate groups")
                    
                    StatBadge(value: analysis.wastedTabs, label: "Wasted", color: .red)
                        .accessibilityLabel("\(analysis.wastedTabs) wasted duplicate tabs")
                }
                
                // Scan telemetry
                if let telemetry = viewModel.scanStats {
                    Divider()
                    
                    HStack {
                        Text("Scan: \(String(format: "%.1f", telemetry.durationSeconds))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Scan completed in \(String(format: "%.1f", telemetry.durationSeconds)) seconds")
                        
                        if telemetry.windowsFailed > 0 {
                            Text("• \(telemetry.windowsFailed) windows failed")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityLabel("\(telemetry.windowsFailed) windows failed to scan")
                        }
                    }
                }
            }
            .padding()
            .background(Color.adaptiveGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Persona card: \(analysis.title)")
    }
}

struct ScanningCard: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section("Scanning...") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: viewModel.scanProgress)
                    .progressViewStyle(.linear)
                    .accessibilityLabel("Scan progress: \(Int(viewModel.scanProgress * 100)) percent")
                
                Text(viewModel.scanMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(viewModel.scanMessage)
            }
            .padding()
        }
        .accessibilityLabel("Scanning in progress")
    }
}

struct WelcomeCard: View {
    var body: some View {
        Section {
            VStack(alignment: .center, spacing: 12) {
                Text("Welcome!")
                    .font(.headline)
                    .accessibilityLabel("Welcome")
                
                Text("Click Scan to analyze your Chrome tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Click Scan to analyze your Chrome tabs")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .accessibilityLabel("Welcome card")
    }
}

struct WindowRow: View {
    let window: WindowInfo
    
    var body: some View {
        HStack {
            Image(systemName: "uiwindow.split.2x1")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading) {
                Text("Window \(window.windowId)")
                    .font(.subheadline)
                    .accessibilityLabel("Window \(window.windowId)")
                
                Text("\(window.tabCount) tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(window.tabCount) tabs")
            }
            
            Spacer()
            
            Text("\(window.tabCount)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Window \(window.windowId), \(window.tabCount) tabs")
        .accessibilityHint("Chrome window information")
    }
}
