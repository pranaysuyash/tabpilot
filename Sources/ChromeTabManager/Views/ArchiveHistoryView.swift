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
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Archives")
                        .font(.headline)
                    Text("Closed tabs will appear here after you close them during a session.")
                        .font(.caption)
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
            
            List(tabs) { tab in
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
        .padding(24)
        .frame(width: 600, height: 400)
    }
}
