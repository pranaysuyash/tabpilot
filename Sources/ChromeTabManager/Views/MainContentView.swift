import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Group {
            if viewModel.isScanning {
                ScanningView(viewModel: viewModel)
                    .accessibilityLabel("Scanning in progress")
            } else if let analysis = viewModel.userAnalysis {
                switch analysis.persona {
                case .light:
                    LightUserView(viewModel: viewModel, analysis: analysis)
                        .accessibilityLabel("Light user view")
                case .superUser:
                    SuperUserView(viewModel: viewModel, analysis: analysis)
                        .accessibilityLabel("Super user view")
                default:
                    StandardUserView(viewModel: viewModel, analysis: analysis)
                        .accessibilityLabel("Standard user view")
                }
            } else {
                EmptyStateView(viewModel: viewModel)
                    .accessibilityLabel("Empty state")
            }
        }
        .navigationTitle("TabPilot")
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(analysis.totalTabs) total tabs")
                    
                    BigStat(value: analysis.duplicateGroups, label: "Duplicates", color: .orange)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(analysis.duplicateGroups) duplicate groups")
                }
                
                if viewModel.hasDuplicates {
                    VStack(spacing: 16) {
                        Text("Cleaning duplicates will make Chrome faster!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Cleaning duplicates will make Chrome faster")
                        
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
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        .accessibilityLabel("Clean all duplicates")
                        .accessibilityHint("Review and close all duplicate tabs, keeping the first-seen tab for each URL")
                        
                        Text("We'll keep the first-seen tab and close the rest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("The first-seen tab will be kept and the rest will be closed")
                    }
                    
                    // Simple list of what's being cleaned
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What we'll clean:")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        
                        ForEach(viewModel.duplicateGroups.prefix(5)) { group in
                            SimpleDuplicateRow(group: group)
                        }
                        
                        if viewModel.duplicateGroups.count > 5 {
                            Text("... and \(viewModel.duplicateGroups.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("And \(viewModel.duplicateGroups.count - 5) more duplicate groups")
                        }
                    }
                    .frame(maxWidth: 500, alignment: .leading)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                            .accessibilityLabel("Success checkmark")
                        
                        Text("No duplicates found!")
                            .font(.title2.bold())
                            .accessibilityLabel("No duplicates found")
                        
                        Text("Your Chrome is already clean and organized.")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Your Chrome is already clean and organized")
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
                            .accessibilityLabel("Filter duplicates")
                            .accessibilityHint("Type to filter duplicate groups by title, URL, or domain. Press Escape to clear.")
                    }
                    
                    // View mode picker
                    Picker("View", selection: $viewModel.viewMode) {
                        ForEach(DuplicateViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                                .help(mode.description)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 400)
                    .help("Change how duplicate tabs are grouped and displayed")
                    .accessibilityLabel("Duplicate view mode")
                    .accessibilityHint("Changes how duplicate tabs are grouped and displayed. Use Command plus number keys to switch.")
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text("\(viewModel.tabs.count) tabs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(viewModel.tabs.count) total tabs")
                        
                        Text("\(viewModel.duplicateGroups.count) groups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Duplicate groups")
                            .accessibilityLabel("\(viewModel.duplicateGroups.count) duplicate groups")
                        
                        Text("\(analysis.wastedTabs) extra")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Tabs beyond the first for each URL")
                            .accessibilityLabel("\(analysis.wastedTabs) wasted duplicate tabs")
                        
                        // Protected domains indicator
                        if !viewModel.protectedDomains.isEmpty {
                            Text("\(viewModel.protectedDomains.count) protected")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .help("Domains excluded from cleanup: \(viewModel.protectedDomains.joined(separator: ", "))")
                                .accessibilityLabel("\(viewModel.protectedDomains.count) protected domains")
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
                        .keyboardShortcut("w", modifiers: .command)
                        .accessibilityLabel("Close \(viewModel.selectedTabIds.count) selected tabs")
                        .accessibilityHint("Closes the selected tabs. Undo is available for 30 seconds.")
                    }
                    
                    Button {
                        viewModel.requestCloseAllDuplicates(keepOldest: true)
                    } label: {
                        Label("Review Cleanup Plan", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
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
                .accessibilityLabel("List of duplicate groups")
            }
            
            // Review Plan overlay with scrim
            if viewModel.showReviewPlan {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.cancelReviewPlan()
                    }
                    .accessibilityLabel("Review plan background")
                
                ReviewPlanView(viewModel: viewModel)
                    .frame(maxWidth: 800, maxHeight: 700)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .padding()
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.showReviewPlan)
                    .accessibilityLabel("Review cleanup plan sheet")
                    .accessibilityHint("Review which tabs will be closed before applying changes")
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
                    ForEach(DuplicateViewMode.allCases, id: \.self) { mode in
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
                            .accessibilityLabel("No duplicates found")
                    }
                }
            }
            .listStyle(.plain)
            .id(viewModel.viewMode)
            .accessibilityLabel("List of duplicate groups")
        }
    }
}

struct ScanningView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .accessibilityLabel("Scanning progress indicator")
            
            Text("Scanning Chrome tabs...")
                .font(.headline)
                .accessibilityLabel("Scanning Chrome tabs")
            
            Text(viewModel.scanMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(viewModel.scanMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanning Chrome tabs, \(viewModel.scanMessage)")
    }
}

struct EmptyStateView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Scan icon")
            
            Text("Scan Your Chrome Tabs")
                .font(.title2.bold())
                .accessibilityLabel("Scan your Chrome tabs")
            
            Button("Scan Now") {
                Task { await viewModel.scan() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("s", modifiers: .command)
            .accessibleLabel("Scan now", hint: "Starts a full scan of all open Chrome windows")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
