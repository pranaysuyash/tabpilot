import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Group {
            if viewModel.isScanning {
                ScanningView(viewModel: viewModel)
            } else if let analysis = viewModel.userAnalysis {
                switch analysis.persona {
                case .light:
                    LightUserView(viewModel: viewModel, analysis: analysis)
                case .superUser:
                    SuperUserView(viewModel: viewModel, analysis: analysis)
                default:
                    StandardUserView(viewModel: viewModel, analysis: analysis)
                }
            } else {
                EmptyStateView(viewModel: viewModel)
            }
        }
        .navigationTitle("Duplicates")
    }
}

struct LightUserView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    let analysis: UserAnalysis
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Big friendly stats
                HStack(spacing: 32) {
                    BigStat(value: analysis.totalTabs, label: "Tabs", color: .blue)
                    BigStat(value: analysis.duplicateGroups, label: "Duplicates", color: .orange)
                }
                
                if viewModel.hasDuplicates {
                    VStack(spacing: 16) {
                        Text("Cleaning duplicates will make Chrome faster!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            viewModel.requestCloseAllDuplicates(keepOldest: true)
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Clean All Duplicates")
                                    .font(.headline)
                            }
                            .frame(maxWidth: 300)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .help("Review and close all duplicate tabs, keeping the first-seen tab for each URL")
                        
                        Text("We'll keep the first-seen tab and close the rest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Simple list of what's being cleaned
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What we'll clean:")
                            .font(.headline)
                        
                        ForEach(viewModel.duplicateGroups.prefix(5)) { group in
                            SimpleDuplicateRow(group: group)
                        }
                        
                        if viewModel.duplicateGroups.count > 5 {
                            Text("... and \(viewModel.duplicateGroups.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 500, alignment: .leading)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                        
                        Text("No duplicates found!")
                            .font(.title2.bold())
                        
                        Text("Your Chrome is already clean and organized.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

struct SuperUserView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    let analysis: UserAnalysis
    
    // Focus state for the search field — Cmd+F triggers this via .focusFilter notification
    enum Field { case search }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Dense toolbar
                HStack(spacing: 16) {
                    if viewModel.config.showSearch {
                        TextField("Filter...", text: $viewModel.searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .focused($focusedField, equals: .search)
                            .help("Filter duplicates by title, URL, or domain (Cmd+F)")
                            .accessibilityLabel("Filter duplicates")
                            .accessibilityHint("Type to filter duplicate groups by title, URL, or domain")
                    }
                    
                    // View mode picker
                    Picker("View", selection: $viewModel.viewMode) {
                        ForEach(TabManagerViewModel.DuplicateViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                                .help(mode.description)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 400)
                    .help("Change how duplicate tabs are grouped and displayed")
                    .accessibilityLabel("Duplicate view mode")
                    .accessibilityHint("Changes how duplicate tabs are grouped and displayed")
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text("\(viewModel.tabs.count) tabs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(viewModel.duplicateGroups.count) groups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Duplicate groups")
                        
                        Text("\(analysis.wastedTabs) extra")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Tabs beyond the first for each URL")
                        
                        // Protected domains indicator
                        if viewModel.licenseManager.isLicensed && !viewModel.protectedDomains.isEmpty {
                            Text("\(viewModel.protectedDomains.count) protected")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .help("Domains excluded from cleanup: \(viewModel.protectedDomains.joined(separator: ", "))")
                        }
                    }
                    
                    // Close Selected button (only if bulk actions enabled and items selected)
                    if viewModel.config.bulkActions && !viewModel.selectedTabIds.isEmpty {
                        Button {
                            viewModel.requestCloseSelected()
                        } label: {
                            Label("Close Selected (\(viewModel.selectedTabIds.count))", systemImage: "xmark.bin")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .help("Close the selected tabs. Undo is available for 30 seconds.")
                        .accessibilityLabel("Close \(viewModel.selectedTabIds.count) selected tabs")
                        .accessibilityHint("Closes the selected tabs. Undo is available for 30 seconds.")
                    }
                    
                    Button {
                        viewModel.requestCloseAllDuplicates(keepOldest: true)
                    } label: {
                        Label("Review Cleanup Plan", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Review which tabs will be closed before applying changes. Matching rules can be changed in Preferences (Cmd+,).")
                    .accessibilityLabel("Review cleanup plan")
                    .accessibilityHint("Opens a review sheet showing which tabs will be closed before applying changes")
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                
                // Dense list
                List(viewModel.filteredDuplicates) { group in
                    SuperDuplicateRow(group: group, viewModel: viewModel)
                }
                .listStyle(.plain)
                .id(viewModel.viewMode) // Force refresh on mode change
            }
            
            // Review Plan overlay with scrim
            if viewModel.showReviewPlan {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.cancelReviewPlan()
                    }
                
                ReviewPlanView(viewModel: viewModel)
                    .frame(maxWidth: 800, maxHeight: 700)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .padding()
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.showReviewPlan)
            }
        }
        // Listen for Cmd+F notification to focus the search field
        .onReceive(NotificationCenter.default.publisher(for: .focusFilter)) { _ in
            guard viewModel.config.showSearch else { return }
            focusedField = .search
        }
    }
}

struct StandardUserView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    let analysis: UserAnalysis
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with view mode
            HStack {
                Picker("View", selection: $viewModel.viewMode) {
                    ForEach(TabManagerViewModel.DuplicateViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Duplicate view mode")
                .accessibilityHint("Changes how duplicate tabs are grouped and displayed")
                
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            List {
                if viewModel.hasDuplicates {
                    ForEach(viewModel.filteredDuplicates) { group in
                        DuplicateGroupSection(group: group, viewModel: viewModel)
                    }
                } else {
                    Section {
                        Text("No duplicates found!")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .id(viewModel.viewMode)
        }
    }
}

struct ScanningView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
            Text("Scanning Chrome tabs...")
                .font(.headline)
            Text(viewModel.scanMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Scan Your Chrome Tabs")
                .font(.title2.bold())
            
            Button("Scan Now") {
                Task { await viewModel.scan() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
