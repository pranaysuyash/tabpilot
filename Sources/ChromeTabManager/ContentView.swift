import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TabManagerViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 280)
        } detail: {
            MainContentView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showPreferences) {
            PreferencesView(viewModel: viewModel)
        }
        .toolbar {
            AppToolbarContent(viewModel: viewModel)
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
                
                // Undo bar (available to all users)
                if viewModel.canUndo {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 12) {
                                Text(viewModel.undoMessage)
                                    .font(.subheadline)
                                
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
}

// MARK: - Toast View

struct ToastView: View {
    let message: String?
    let isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            if isShowing, let message = message {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                    Text(message)
                        .font(.subheadline)
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                .padding(.bottom, 20)
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        List {
            if let analysis = viewModel.userAnalysis {
                PersonaCard(analysis: analysis, viewModel: viewModel)
            } else if viewModel.isScanning {
                ScanningCard(viewModel: viewModel)
            } else {
                WelcomeCard()
            }
            
            if let analysis = viewModel.userAnalysis, analysis.persona != .light {
                if viewModel.config.showWindowBreakdown {
                    Section("Windows") {
                        ForEach(viewModel.windows) { window in
                            WindowRow(window: window)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tab Manager")
    }
}

struct PersonaCard: View {
    let analysis: UserAnalysis
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(analysis.icon)
                        .font(.system(size: 40))
                    VStack(alignment: .leading) {
                        Text(analysis.title)
                            .font(.headline)
                        Text(analysis.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatBadge(value: analysis.totalTabs, label: "Tabs", color: Color.blue)
                    StatBadge(value: analysis.windowCount, label: "Windows", color: .purple)
                    StatBadge(value: analysis.duplicateGroups, label: "Duplicates", color: .orange)
                    StatBadge(value: analysis.wastedTabs, label: "Wasted", color: .red)
                }
                
                // Scan telemetry
                if let telemetry = viewModel.scanStats {
                    Divider()
                    
                    HStack {
                        Text("Scan: \(String(format: "%.1f", telemetry.durationSeconds))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if telemetry.windowsFailed > 0 {
                            Text("• \(telemetry.windowsFailed) windows failed")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ScanningCard: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section("Scanning...") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: viewModel.scanProgress)
                    .progressViewStyle(.linear)
                Text(viewModel.scanMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct WelcomeCard: View {
    var body: some View {
        Section {
            VStack(alignment: .center, spacing: 12) {
                Text("Welcome!")
                    .font(.headline)
                Text("Click Scan to analyze your Chrome tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

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

// MARK: - Persona-Specific Views

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
                        
                        // Protected domains indicator (Pro only)
                        if viewModel.licenseManager.isPro && !viewModel.protectedDomains.isEmpty {
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
                        .help("Close the selected tabs. Pro users can undo for 30 seconds.")
                    }
                    
                    Button {
                        viewModel.requestCloseAllDuplicates(keepOldest: true)
                    } label: {
                        Label("Review Cleanup Plan", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Review which tabs will be closed before applying changes. Matching rules can be changed in Preferences (Cmd+,).")
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

// MARK: - Supporting Views

struct BigStat: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SimpleDuplicateRow: View {
    let group: DuplicateGroup
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.tabs.first?.title ?? "Unknown")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(group.displayUrl)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(group.tabs.count) copies")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct SuperDuplicateRow: View {
    let group: DuplicateGroup
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.tabs.first?.title ?? "Unknown")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(group.displayUrl)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            let windows = Set(group.tabs.map { $0.windowId }).sorted()
            Text("W\(windows.map(String.init).joined(separator: ","))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text("\(group.tabs.count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule())
            
            Button {
                viewModel.selectAllExceptOldest(in: group)
            } label: {
                Image(systemName: "1.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Keep first seen")
            
            Button {
                Task {
                    if let first = group.tabs.first {
                        await viewModel.activateTab(first)
                    }
                }
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Focus tab in Chrome")
        }
        .padding(.vertical, 6)
    }
}

// Rest of views (ScanningView, EmptyStateView, DuplicateGroupSection, etc.) from previous version...
// Include them here or reference them

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

struct DuplicateGroupSection: View {
    let group: DuplicateGroup
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.tabs.first?.title.prefix(60) ?? "Untitled")
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(group.displayUrl.prefix(80))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(group.tabs.count) copies")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    ActionButton(title: "Keep First Seen", icon: "1.circle.fill", color: .green) {
                        viewModel.selectAllExceptOldest(in: group)
                    }
                    
                    ActionButton(title: "Keep Last Seen", icon: "star.circle.fill", color: .blue) {
                        viewModel.selectAllExceptNewest(in: group)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    ForEach(group.tabs) { tab in
                        TabRow(
                            tab: tab,
                            isOldest: tab.id == group.oldestTab?.id,
                            isNewest: tab.id == group.newestTab?.id,
                            isSelected: viewModel.selectedTabIds.contains(tab.id),
                            showAge: viewModel.config.showAge
                        ) {
                            viewModel.toggleSelection(tab)
                        } onFocus: {
                            await viewModel.activateTab(tab)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WindowRow: View {
    let window: WindowInfo
    
    var body: some View {
        HStack {
            Image(systemName: "uiwindow.split.2x1")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text("Window \(window.windowId)")
                    .font(.subheadline)
                Text("\(window.tabCount) tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(window.tabCount)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct TabRow: View {
    let tab: TabInfo
    let isOldest: Bool
    let isNewest: Bool
    let isSelected: Bool
    let showAge: Bool
    let onToggle: () -> Void
    let onFocus: () async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: .init(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            
            HStack(spacing: 4) {
                if isOldest {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(.green)
                    Text("FIRST")
                        .foregroundStyle(.green)
                } else if isNewest {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.blue)
                    Text("LAST")
                        .foregroundStyle(.blue)
                }
            }
            .font(.caption.bold())
            .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("Window \(tab.windowId) • Tab \(tab.tabIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if showAge {
                Text(tab.ageDescription)
                    .font(.caption)
                    .foregroundStyle(ageColor)
            }
            
            Button {
                Task { await onFocus() }
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Focus tab in Chrome")
        }
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    var ageColor: Color {
        let seconds = Date().timeIntervalSince(tab.openedAt)
        if seconds >= 86400 { return .red }
        if seconds >= 3600 { return .orange }
        return .green
    }
}

struct AppToolbarContent: ToolbarContent {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some SwiftUI.ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let analysis = viewModel.userAnalysis, analysis.persona != .light {
                // View mode buttons
                ForEach(TabManagerViewModel.DuplicateViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.viewMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                    .keyboardShortcut(viewModeShortcut(for: mode), modifiers: .command)
                }
                
                Button(action: { Task { await viewModel.scan() } }) {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

func viewModeShortcut(for mode: TabManagerViewModel.DuplicateViewMode) -> KeyEquivalent {
    switch mode {
    case .overall: return "1"
    case .byWindow: return "2"
    case .byDomain: return "3"
    case .crossWindow: return "4"
    }
}

// MARK: - Review Plan View

struct ReviewPlanView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var totalToClose: Int {
        viewModel.reviewPlanItems.filter { $0.isIncluded }.reduce(0) { $0 + $1.closeTabs.count }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Cleanup Plan")
                        .font(.title2.bold())
                    Text("\(viewModel.reviewPlanItems.count) groups • Closing \(totalToClose) tabs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        viewModel.cancelReviewPlan()
                    } label: {
                        Text("Cancel")
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button {
                        Task { await viewModel.executeReviewPlan() }
                    } label: {
                        Label("Close \(totalToClose) Tabs", systemImage: "xmark.bin")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(totalToClose == 0)
                    .keyboardShortcut(.defaultAction)
                    .help("Permanently close the selected tabs")
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            // Plan items
            List($viewModel.reviewPlanItems) { $item in
                ReviewPlanItemRow(item: $item)
            }
            .listStyle(.plain)
        }
        .background(Color(.controlBackgroundColor))
    }
}

struct ReviewPlanItemRow: View {
    @Binding var item: TabManagerViewModel.ReviewPlanItem
    
    var body: some View {
        HStack(spacing: 16) {
            Toggle("", isOn: $item.isIncluded)
                .toggleStyle(.checkbox)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.group.displayUrl)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(item.keepTab.title.prefix(40), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Text("KEEP")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                
                Text("Closing \(item.closeTabs.count) tabs:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(item.closeTabs) { tab in
                    Label(tab.title.prefix(50), systemImage: "xmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 16)
                }
            }
            
            Spacer()
            
            Text("\(item.closeTabs.count)")
                .font(.title2.bold())
                .foregroundStyle(item.isIncluded ? .red : .secondary)
        }
        .padding(.vertical, 8)
        .opacity(item.isIncluded ? 1.0 : 0.5)
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                
                Text(PaywallCopy.title)
                    .font(.largeTitle.bold())
                
                Text(PaywallCopy.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Pricing
            Text(PaywallCopy.price)
                .font(.title2.bold())
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(PaywallCopy.features, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    Task {
                        let success = await licenseManager.purchasePro()
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if licenseManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(PaywallCopy.callToAction)
                            .font(.headline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(licenseManager.isLoading)
                
                Button {
                    Task {
                        let restored = await licenseManager.restorePurchases()
                        if restored {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Restore Purchases")
                }
                .buttonStyle(.plain)
                .disabled(licenseManager.isLoading)
                
                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .frame(width: 500, height: 600)
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
