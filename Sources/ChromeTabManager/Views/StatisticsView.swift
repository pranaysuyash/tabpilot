import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var stats: TabStatistics?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Usage Statistics")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            if let stats = stats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Sessions", value: "\(stats.sessionsCount)", icon: "clock")
                    StatCard(title: "Tabs Closed", value: "\(stats.totalTabsClosed)", icon: "xmark.circle")
                    StatCard(title: "Duplicates Closed", value: "\(stats.duplicateTabsClosed)", icon: "doc.on.doc")
                    StatCard(title: "Time Saved", value: formatTimeSaved(stats.totalSavingsSeconds), icon: "clock.fill")
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Overview")
                        .font(.headline)
                    
                    HStack {
                        Text("Current Tabs:")
                        Spacer()
                        Text("\(viewModel.tabs.count)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Open Windows:")
                        Spacer()
                        Text("\(viewModel.windows.count)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Duplicate Groups:")
                        Spacer()
                        Text("\(viewModel.duplicateGroups.count)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Total Wasted Tabs:")
                        Spacer()
                        Text("\(viewModel.duplicateGroups.reduce(0) { $0 + $1.wastedCount })")
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            } else {
                ProgressView("Loading statistics...")
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 450, height: 400)
        .onAppear {
            loadStats()
        }
    }
    
    private func loadStats() {
        stats = StatisticsStore.shared.getStats()
    }
    
    private func formatTimeSaved(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.textBackgroundColor))
        .cornerRadius(12)
    }
}
