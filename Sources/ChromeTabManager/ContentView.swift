import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel: TabManagerViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var exportDocument: TabExportDocument?
    @State private var exportDefaultFilename = "ChromeTabs.md"
    @State private var showingFileExporter = false
    @State private var showingFileImporter = false
    @State private var showingArchiveSheet = false
    @State private var archiveFileName = ""
    @State private var archiveFormat: TabManagerViewModel.ExportFormat = .markdown
    @State private var archiveAppend = false

    init(viewModel: TabManagerViewModel = TabViewModelBuilder().build()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 280)
        } detail: {
            MainContentView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPreferences) {
            PreferencesView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showExtensionInstallationGuide) {
            ExtensionInstallationGuide()
        }
        .sheet(isPresented: $showingArchiveSheet) {
            ArchiveSheetView(
                fileName: $archiveFileName,
                format: $archiveFormat,
                append: $archiveAppend
            ) {
                viewModel.archiveSelectedTabs(fileName: archiveFileName, format: archiveFormat, append: archiveAppend)
                showingArchiveSheet = false
            } onCancel: {
                showingArchiveSheet = false
            }
        }
        .sheet(isPresented: $viewModel.isImportResultPresented) {
            ImportResultView(
                importedTabs: viewModel.importPreviewTabs,
                onOpenInChrome: {
                    Task { await viewModel.openImportedTabs(viewModel.importPreviewTabs) }
                    viewModel.isImportResultPresented = false
                },
                onCancel: {
                    viewModel.isImportResultPresented = false
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .toolbar {
            AppToolbarContent(viewModel: viewModel)
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Menu("Export Selected") {
                        ForEach(TabManagerViewModel.ExportFormat.allCases, id: \.self) { format in
                            Button(format.rawValue) {
                                prepareExportSelected(format: format)
                            }
                        }
                    }
                    Button("Archive Selected…") {
                        archiveFormat = viewModel.defaultExportFormat
                        showingArchiveSheet = true
                    }
                    Divider()
                    Button("Import from Bookmarks…") {
                        showingFileImporter = true
                    }
                } label: {
                    Label("Export/Import", systemImage: "square.and.arrow.up.on.square")
                }
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: exportDefaultFilename
        ) { result in
            if case .failure(let error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.html, .json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    let imported = await viewModel.importTabs(from: url)
                    await MainActor.run {
                        viewModel.importPreviewTabs = imported
                        viewModel.isImportResultPresented = true
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(viewModel.confirmationTitle, isPresented: $viewModel.showConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelConfirmation()
            }
            Button("Close", role: .destructive) {
                Task { await viewModel.executeConfirmation() }
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
        .overlay(
            ZStack {
                ToastView(message: viewModel.toastMessage, isShowing: viewModel.showToast)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showToast)
                
                // Undo bar
                if viewModel.canUndo {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 12) {
                                Text(viewModel.undoMessage)
                                    .font(.subheadline)
                                
                                Text("(\(Int(viewModel.undoTimeRemaining))s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    Task { await viewModel.undoLastClose() }
                                } label: {
                                    Label("Undo", systemImage: "arrow.uturn.backward")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                
                                Button {
                                    viewModel.dismissUndo()
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color(.windowBackgroundColor))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        )
    }

    private func prepareExportSelected(format: TabManagerViewModel.ExportFormat) {
        let selected = viewModel.tabs.filter { viewModel.selectedTabIds.contains($0.id) }
        guard !selected.isEmpty else {
            viewModel.displayToast(message: "Select tabs to export first")
            return
        }

        let content = viewModel.exportContent(for: selected, format: format)
        exportDocument = TabExportDocument(text: content)
        exportDefaultFilename = "ChromeTabs-\(DateFormats.isoDateOnly.string(from: Date())).\(format.fileExtension)"
        showingFileExporter = true
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}

private struct TabExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private struct ArchiveSheetView: View {
    @Binding var fileName: String
    @Binding var format: TabManagerViewModel.ExportFormat
    @Binding var append: Bool
    let onArchive: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Archive Selected Tabs")
                .font(.title3.bold())

            TextField("File name (optional)", text: $fileName)
                .textFieldStyle(.roundedBorder)

            Picker("Format", selection: $format) {
                ForEach(TabManagerViewModel.ExportFormat.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Append to existing file", isOn: $append)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Archive", action: onArchive)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420)
    }
}

private struct ImportResultView: View {
    let importedTabs: [ImportTab]
    let onOpenInChrome: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Imported Tabs")
                .font(.title3.bold())
            Text("\(importedTabs.count) tabs ready to open")
                .foregroundStyle(.secondary)

            List(importedTabs) { tab in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title).lineLimit(1)
                    Text(tab.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 240)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Open in Chrome", action: onOpenInChrome)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 620, height: 420)
    }
}
