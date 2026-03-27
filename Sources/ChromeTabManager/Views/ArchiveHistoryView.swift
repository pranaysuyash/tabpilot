import SwiftUI

@available(macOS 14.0, *)
struct ArchiveHistoryView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var archives: [ArchiveEntry] = []
    @State private var selectedArchive: ArchiveEntry?
    @State private var archivedTabs: [ArchivedTab] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Archive History")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
             if archives.isEmpty {
                 VStack(spacing: 12) {
                     Image(systemName: "archivebox")
                         .font(.system(.title)) // Using system font for dynamic type
                         .foregroundStyle(.secondary)
                     Text("No Archives")
                         .font(.title3) // Using system font for dynamic type
                     Text("Closed tabs will appear here after you close them during a session.")
                         .font(.subheadline) // Using system font for dynamic type
                         .fontWeight(.regular)
                         .foregroundStyle(.secondary)
                         .multilineTextAlignment(.center)
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(archives) { archive in
                    Button {
                        loadArchive(archive)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(archive.formattedDate)
                                    .font(.headline)
                                Text("\(archive.tabCount) tabs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if archive.isToday {
                                Text("Today")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Image(systemName: "arrow.down.to.line")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .onAppear {
            loadArchives()
        }
        .sheet(item: $selectedArchive) { archive in
            ArchiveDetailView(archive: archive, tabs: archivedTabs)
        }
    }
    
    private func loadArchives() {
        isLoading = true
        Task {
            archives = await AutoArchiveManager.shared.availableArchives()
            isLoading = false
        }
    }
    
    private func loadArchive(_ archive: ArchiveEntry) {
        isLoading = true
        Task {
            archivedTabs = await AutoArchiveManager.shared.loadArchive(from: archive.fileURL)
            selectedArchive = archive
            isLoading = false
        }
    }
}

struct ArchiveDetailView: View {
    let archive: ArchiveEntry
    let tabs: [ArchivedTab]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTabs: Set<String> = []
    @State private var isRestoring = false
    @State private var showSuccess = false
    @State private var restoredCount = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(archive.formattedDate)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            
            HStack {
                Button("Restore Selected (\(selectedTabs.count))") {
                    restoreSelected()
                }
                .disabled(selectedTabs.isEmpty || isRestoring)
                
                Button("Restore All (\(tabs.count))") {
                    restoreAll()
                }
                .disabled(isRestoring)
                
                Spacer()
                
                Button(selectedTabs.count == tabs.count ? "Deselect All" : "Select All") {
                    if selectedTabs.count == tabs.count {
                        selectedTabs.removeAll()
                    } else {
                        selectedTabs = Set(tabs.map { $0.id.uuidString })
                    }
                }
            }
            
            List(tabs) { tab in
                HStack {
                    Button {
                        toggleSelection(tab)
                    } label: {
                        Image(systemName: selectedTabs.contains(tab.id.uuidString) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTabs.contains(tab.id.uuidString) ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading) {
                        Text(tab.title)
                            .font(.headline)
                        Text(tab.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 600, height: 400)
        .overlay {
            if isRestoring {
                ProgressView("Restoring tabs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert("Restored \(restoredCount) tabs", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        }
    }
    
    private func toggleSelection(_ tab: ArchivedTab) {
        let id = tab.id.uuidString
        if selectedTabs.contains(id) {
            selectedTabs.remove(id)
        } else {
            selectedTabs.insert(id)
        }
    }
    
    private func restoreSelected() {
        let tabsToRestore = tabs.filter { selectedTabs.contains($0.id.uuidString) }
        performRestore(tabsToRestore)
    }
    
    private func restoreAll() {
        performRestore(tabs)
    }
    
    private func performRestore(_ tabsToRestore: [ArchivedTab]) {
        isRestoring = true
        Task {
            restoredCount = await AutoArchiveManager.shared.restoreTabs(tabsToRestore)
            isRestoring = false
            showSuccess = true
        }
    }
}
