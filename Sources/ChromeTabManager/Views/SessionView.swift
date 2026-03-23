import SwiftUI

/// Session manager view — save, browse, and restore Chrome tab sessions.
struct SessionView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @StateObject private var sessionStore = SessionStore.shared
    
    @State private var showSaveSheet = false
    @State private var sessionName = ""
    @State private var sessionToDelete: Session?
    @State private var sessionToRename: Session?
    @State private var renameText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sessions")
                        .font(.title3.bold())
                    Text("\(sessionStore.sessions.count) saved sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    sessionName = "Session \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
                    showSaveSheet = true
                } label: {
                    Label("Save Current Tabs", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.tabs.isEmpty)
                .help("Save all current Chrome tabs as a session")
            }
            .padding()
            .background(.ultraThinMaterial)
            
            if sessionStore.sessions.isEmpty {
                SessionEmptyState()
            } else {
                List(sessionStore.sessions) { session in
                    SessionRow(session: session, viewModel: viewModel) {
                        sessionStore.delete(session)
                    } onRename: {
                        sessionToRename = session
                        renameText = session.name
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveSessionSheet(
                sessionName: $sessionName,
                tabCount: viewModel.tabs.count
            ) { name in
                sessionStore.saveCurrentTabs(viewModel.tabs, name: name)
            }
        }
        .alert("Rename Session", isPresented: Binding(
            get: { sessionToRename != nil },
            set: { if !$0 { sessionToRename = nil } }
        )) {
            TextField("Session name", text: $renameText)
            Button("Rename") {
                if let session = sessionToRename {
                    sessionStore.rename(session, to: renameText)
                }
                sessionToRename = nil
            }
            Button("Cancel", role: .cancel) { sessionToRename = nil }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session
    @ObservedObject var viewModel: TabManagerViewModel
    let onDelete: () -> Void
    let onRename: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }
                
                // Session info
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.headline)
                    Text("\(session.tabCount) tabs · \(session.domainSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Actions
                HStack(spacing: 8) {
                    Button {
                        Task { await restoreSession() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .help("Reopen all tabs in this session")
                    
                    Button {
                        onRename()
                    } label: {
                        Image(systemName: "pencil.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Rename session")
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Delete session")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }
            
            // Expanded tab list
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.tabs.prefix(10)) { tab in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue.opacity(0.5))
                                .frame(width: 6, height: 6)
                            Text(tab.title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(tab.domain)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if session.tabs.count > 10 {
                        Text("... and \(session.tabs.count - 10) more tabs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .background(Color.clear)
    }
    
    private func restoreSession() async {
        for tab in session.tabs {
            let success = await ChromeController.shared.openTab(windowId: tab.windowId, url: tab.url)
            if success {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        SessionStore.shared.markOpened(session)
    }
}

// MARK: - Empty State

struct SessionEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("No Saved Sessions")
                .font(.title3.bold())
            
            Text("Save your current tabs as a session to reopen them later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Save Sheet

struct SaveSessionSheet: View {
    @Binding var sessionName: String
    let tabCount: Int
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            
            Text("Save Session")
                .font(.title2.bold())
            
            Text("Saving \(tabCount) tabs")
                .foregroundStyle(.secondary)
            
            TextField("Session name", text: $sessionName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
            
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    onSave(sessionName.isEmpty ? "Untitled Session" : sessionName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(sessionName.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 400)
    }
}
