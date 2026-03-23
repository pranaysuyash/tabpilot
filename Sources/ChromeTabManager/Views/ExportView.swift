import SwiftUI

/// Export View — lets users export their tabs or duplicate groups to various formats.
struct ExportView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportManager.ExportFormat = .markdown
    @State private var exportContent = ""
    @State private var selectedDataType: DataType = .allTabs
    @State private var copySuccess = false
    
    enum DataType: String, CaseIterable {
        case allTabs = "All Tabs"
        case duplicatesOnly = "Duplicates Only"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Tabs")
                        .font(.title2.bold())
                    Text("\(viewModel.tabs.count) tabs available to export")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Options
            HStack(spacing: 20) {
                Picker("Data", selection: $selectedDataType) {
                    ForEach(DataType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportManager.ExportFormat.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(exportContent, forType: .string)
                        withAnimation { copySuccess = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { copySuccess = false }
                        }
                    } label: {
                        Label(
                            copySuccess ? "Copied!" : "Copy",
                            systemImage: copySuccess ? "checkmark.circle.fill" : "doc.on.clipboard"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(copySuccess ? .green : .primary)
                }
            }
            .padding()
            
            Divider()
            
            // Preview
            ScrollView {
                Text(exportContent)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .background(Color(.textBackgroundColor))
        }
        .frame(width: 700, height: 500)
        .onAppear { generateContent() }
        .onChange(of: selectedFormat) { _, _ in generateContent() }
        .onChange(of: selectedDataType) { _, _ in generateContent() }
    }
    
    private func generateContent() {
        switch selectedDataType {
        case .allTabs:
            exportContent = ExportManager.export(tabs: viewModel.tabs, format: selectedFormat)
        case .duplicatesOnly:
            exportContent = ExportManager.exportDuplicates(groups: viewModel.duplicateGroups, format: selectedFormat)
        }
    }
}
