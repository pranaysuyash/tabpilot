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
                }
                
                Section("Tab Health") {
                    TabDebtView(viewModel: viewModel)
                        .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tab Manager")
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
                    VStack(alignment: .leading) {
                        Text(analysis.title)
                            .font(.headline)
                        Text(analysis.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
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
                        
                        if telemetry.windowsFailed > 0 {
                            Text("• \(telemetry.windowsFailed) windows failed")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ScanningCard: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section("Scanning...") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: viewModel.scanProgress)
                    .progressViewStyle(.linear)
                Text(viewModel.scanMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct WelcomeCard: View {
    var body: some View {
        Section {
            VStack(alignment: .center, spacing: 12) {
                Text("Welcome!")
                    .font(.headline)
                Text("Click Scan to analyze your Chrome tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

struct WindowRow: View {
    let window: WindowInfo
    
    var body: some View {
        HStack {
            Image(systemName: "uiwindow.split.2x1")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text("Window \(window.windowId)")
                    .font(.subheadline)
                Text("\(window.tabCount) tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(window.tabCount)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Window \(window.windowId), \(window.tabCount) tabs")
    }
}
