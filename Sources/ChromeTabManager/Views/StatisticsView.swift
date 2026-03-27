import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var stats: TabStatistics?
    
    // Export states
    @State private var showExportSheet = false
    @State private var exportFormat: ExportManager.HistoryExportFormat = .csv
    @State private var exportDateRange: ExportManager.ExportDateRange = .last7Days
    @State private var isExporting = false
    @State private var exportError: Error?
    @State private var showExportError = false
    @State private var availableHistoryDays: Int = 0
    
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
                .background(Color.adaptiveTextBackground)
                .cornerRadius(8)
                
                // Export Section
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export History")
                                .font(.headline)
                            if availableHistoryDays > 0 {
                                Text("\(availableHistoryDays) days of data available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No historical data available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            showExportSheet = true
                        } label: {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(availableHistoryDays == 0)
                    }
                }
                .padding()
                .background(Color.adaptiveTextBackground)
                .cornerRadius(8)
            } else {
                ProgressView("Loading statistics...")
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 500)
        .onAppear {
            loadStats()
            loadHistoryInfo()
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
        .alert("Export Error", isPresented: $showExportError, presenting: exportError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            if let exportError = error as? ExportError {
                Text(exportError.errorDescription ?? "An unknown error occurred.")
            } else {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var exportSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Export Time Tracking Data")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    showExportSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportManager.HistoryExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Date Range")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Date Range", selection: $exportDateRange) {
                    ForEach(ExportManager.ExportDateRange.allCases, id: \.self) { range in
                        if availableHistoryDays >= range.days {
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showExportSheet = false
                }
                .buttonStyle(.bordered)
                
                Button {
                    performExport()
                } label: {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Export", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .padding(24)
        .frame(width: 350, height: 280)
    }
    
    private func loadStats() {
        stats = StatisticsStore.shared.getStats()
    }
    
    private func loadHistoryInfo() {
        Task {
            let days = await TabTimeStore.shared.availableHistoryDays
            await MainActor.run {
                availableHistoryDays = days
            }
        }
    }
    
    private func performExport() {
        Task {
            isExporting = true
            defer { isExporting = false }
            
            do {
                try await ExportManager.exportHistory(
                    format: exportFormat,
                    days: exportDateRange.days
                )
                await MainActor.run {
                    showExportSheet = false
                }
            } catch {
                await MainActor.run {
                    exportError = error
                    showExportError = true
                }
            }
        }
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
        .background(Color.adaptiveTextBackground)
        .cornerRadius(12)
    }
}
