import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            GeneralPreferences(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            DuplicatePreferences(viewModel: viewModel)
                .tabItem {
                    Label("Duplicates", systemImage: "doc.on.doc")
                }

            ExportImportPreferences(viewModel: viewModel)
                .tabItem {
                    Label("Export/Import", systemImage: "square.and.arrow.up.on.square")
                }
            
            if viewModel.licenseManager.isLicensed {
                ProtectionPreferences(viewModel: viewModel)
                    .tabItem {
                        Label("Protection", systemImage: "shield")
                    }
            }
        }
        .frame(width: 500, height: 400)
        .padding()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            // Ensure we can always dismiss even during scans
            viewModel.isPreferencesOpen = true
        }
        .onDisappear {
            viewModel.isPreferencesOpen = false
        }
        // Support Esc and Cmd+W to close
        .onExitCommand {
            dismiss()
        }
    }
}

struct GeneralPreferences: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Form {
            Section("Keep Policy") {
                Picker("Default Keep", selection: $viewModel.defaultKeepPolicy) {
                    Text("First Seen").tag("first")
                    Text("Last Seen").tag("last")
                }
                .pickerStyle(.segmented)
                
                Text("When closing duplicates, keep tabs based on when they were first seen in this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Confirmation") {
                Toggle("Confirm destructive actions", isOn: $viewModel.confirmDestructive)
                
                Text("Show confirmation dialog before closing multiple tabs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct DuplicatePreferences: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Form {
            Section("Matching") {
                Toggle("Ignore tracking parameters", isOn: $viewModel.ignoreTrackingParams)
                
                Text("Removes utm_, fbclid, gclid and other tracking parameters when comparing URLs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Strip query parameters", isOn: $viewModel.stripQueryParams)
                
                Text("Compare URLs without query parameters (more aggressive matching).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Display") {
                Picker("Max duplicates shown", selection: $viewModel.maxDuplicatesDisplay) {
                    Text("5").tag(5)
                    Text("20").tag(20)
                    Text("100").tag(100)
                    Text("All").tag(10000)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ProtectionPreferences: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Form {
            Section("Protected Domains") {
                Text("Tabs from these domains will never be shown as duplicates or closed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                List {
                    ForEach(viewModel.protectedDomains, id: \.self) { domain in
                        HStack {
                            Text(domain)
                            Spacer()
                            Button("Remove") {
                                viewModel.removeProtectedDomain(domain)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                    .onDelete { indexSet in
                        viewModel.protectedDomains.remove(atOffsets: indexSet)
                    }
                }
                
                HStack {
                    TextField("Add domain (e.g., mail.google.com)", text: $viewModel.newProtectedDomain)
                    Button("Add") {
                        viewModel.addProtectedDomain()
                    }
                    .disabled(viewModel.newProtectedDomain.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ExportImportPreferences: View {
    @ObservedObject var viewModel: TabManagerViewModel

    var body: some View {
        Form {
            Section("Defaults") {
                Picker("Default export format", selection: Binding(
                    get: { viewModel.defaultExportFormat },
                    set: { viewModel.defaultExportFormat = $0 }
                )) {
                    ForEach(TabManagerViewModel.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
            }

            Section("Archive Location") {
                Text(viewModel.archiveDirectoryURL().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack {
                    Button("Choose Location…") {
                        viewModel.chooseArchiveDirectory()
                    }
                    Button("Open in Finder") {
                        viewModel.openArchiveDirectoryInFinder()
                    }
                }
            }

            Section("Recent Archives") {
                if viewModel.recentArchives.isEmpty {
                    Text("No recent archives")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.recentArchives, id: \.path) { archiveURL in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(archiveURL.lastPathComponent)
                                Text(archiveURL.path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Open") {
                                viewModel.openArchiveFile(archiveURL)
                            }
                            .buttonStyle(.borderless)
                            Button("Delete") {
                                viewModel.deleteArchiveFile(archiveURL)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
