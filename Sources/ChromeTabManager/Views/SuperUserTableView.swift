import SwiftUI

struct SuperUserTableView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    let analysis: UserAnalysis
    
    @State private var sortOrder: SortOrder = .title
    @State private var sortDirection: SortDirection = .ascending

    @State private var focusedGroupIndex: Int = 0
    @State private var selectionAnchor: Int?
    @FocusState private var isTableFocused: Bool
    
    private var sortedGroups: [DuplicateGroup] {
        let groups = viewModel.filteredDuplicates
        return groups.sorted { lhs, rhs in
            let comparison: Bool
            switch sortOrder {
            case .title:
                comparison = lhs.tabs.first?.title ?? "" < rhs.tabs.first?.title ?? ""
            case .domain:
                comparison = (lhs.tabs.first?.urlDomain ?? "") < (rhs.tabs.first?.urlDomain ?? "")
            case .window:
                comparison = lhs.tabs.first?.windowId ?? 0 < rhs.tabs.first?.windowId ?? 0
            case .count:
                comparison = lhs.tabs.count < rhs.tabs.count
            case .age:
                comparison = lhs.tabs.first?.openedAt ?? Date() < rhs.tabs.first?.openedAt ?? Date()
            }
            return sortDirection == .ascending ? comparison : !comparison
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case title = "Title"
        case domain = "Domain"
        case window = "Window"
        case count = "Count"
        case age = "Age"
    }
    
    enum SortDirection {
        case ascending, descending
        
        var icon: String {
            switch self {
            case .ascending: return "arrow.up"
            case .descending: return "arrow.down"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                sortableHeader("Title", order: .title, width: 300)
                sortableHeader("Domain", order: .domain, width: 180)
                sortableHeader("Window", order: .window, width: 80)
                sortableHeader("Count", order: .count, width: 70)
                sortableHeader("Age", order: .age, width: 100)
                Spacer()
                    .frame(width: 60)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor)),
                alignment: .bottom
            )
            
            // Table rows
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sortedGroups.enumerated()), id: \.element.id) { index, group in
                            TableRow(
                                group: group,
                                viewModel: viewModel,
                                isFocused: focusedGroupIndex == index
                            )
                            .id(group.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                focusedGroupIndex = index
                                selectionAnchor = nil
                                toggleSelection(for: group)
                                announceCurrentRow()
                            }
                            .background(
                                isSelected(group) ? Color.accentColor.opacity(0.1) :
                                    (focusedGroupIndex == index ? Color(.selectedControlColor).opacity(0.1) : Color.clear)
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(accessibilityLabel(for: group, at: index))
                            .accessibilityHint("Press space to select, return to activate, command+return to close duplicates")
                            .accessibilityAddTraits(.isButton)

                            Divider()
                        }
                    }
                }
                .onChange(of: focusedGroupIndex) { _, _ in
                    guard !sortedGroups.isEmpty, focusedGroupIndex < sortedGroups.count else { return }
                    let id = sortedGroups[focusedGroupIndex].id
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .focusable()
            .focused($isTableFocused)
            .focusEffectDisabled()
            .onKeyPress(phases: .down) { press in
                handleTableKeyPress(press)
            }
            
            // Status bar
            HStack {
                Text("\(sortedGroups.count) groups • \(analysis.totalTabs) tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Sorted by \(sortOrder.rawValue) \(sortDirection == .ascending ? "↑" : "↓")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.windowBackgroundColor))
        }
    }
    
    private func sortableHeader(_ title: String, order: SortOrder, width: CGFloat) -> some View {
        Button {
            if sortOrder == order {
                sortDirection = sortDirection == .ascending ? .descending : .ascending
            } else {
                sortOrder = order
                sortDirection = .ascending
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(sortOrder == order ? .semibold : .regular)
                
                if sortOrder == order {
                    Image(systemName: sortDirection.icon)
                        .font(.caption2)
                }
            }
            .foregroundStyle(sortOrder == order ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .leading)
    }
    
    private func isSelected(_ group: DuplicateGroup) -> Bool {
        group.tabs.contains { viewModel.selectedTabIds.contains($0.id) }
    }
    
    private func handleTableKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            if focusedGroupIndex > 0 {
                let newIndex = focusedGroupIndex - 1
                if press.modifiers.contains(.shift) {
                    applyRangeSelection(to: newIndex)
                } else {
                    focusedGroupIndex = newIndex
                    selectionAnchor = nil
                }
                announceCurrentRow()
            }
            return .handled
        case .downArrow:
            if focusedGroupIndex < sortedGroups.count - 1 {
                let newIndex = focusedGroupIndex + 1
                if press.modifiers.contains(.shift) {
                    applyRangeSelection(to: newIndex)
                } else {
                    focusedGroupIndex = newIndex
                    selectionAnchor = nil
                }
                announceCurrentRow()
            }
            return .handled
        case .pageUp:
            let jump = max(1, focusedGroupIndex - 10)
            focusedGroupIndex = max(0, jump)
            selectionAnchor = nil
            announceCurrentRow()
            return .handled
        case .pageDown:
            let jump = min(sortedGroups.count - 1, focusedGroupIndex + 10)
            focusedGroupIndex = jump
            selectionAnchor = nil
            announceCurrentRow()
            return .handled
        case .home:
            focusedGroupIndex = 0
            selectionAnchor = nil
            announceCurrentRow()
            return .handled
        case .end:
            focusedGroupIndex = max(0, sortedGroups.count - 1)
            selectionAnchor = nil
            announceCurrentRow()
            return .handled
        case .space:
            if focusedGroupIndex < sortedGroups.count {
                toggleSelection(for: sortedGroups[focusedGroupIndex])
            }
            return .handled
        case .return:
            if press.modifiers == .command {
                if focusedGroupIndex < sortedGroups.count {
                    let group = sortedGroups[focusedGroupIndex]
                    if group.tabs.count > 1 {
                        for tab in group.tabs.dropFirst() {
                            viewModel.selectedTabIds.insert(tab.id)
                        }
                        viewModel.requestCloseSelected()
                    }
                }
            } else {
                if focusedGroupIndex < sortedGroups.count {
                    Task {
                        if let firstTab = sortedGroups[focusedGroupIndex].tabs.first {
                            await viewModel.activateTab(firstTab)
                        }
                    }
                }
            }
            return .handled
        case .escape:
            deselectAll()
            selectionAnchor = nil
            return .handled
        default:
            return .ignored
        }
    }
    
    private func announceCurrentRow() {
        guard focusedGroupIndex < sortedGroups.count else { return }
        let label = accessibilityLabel(for: sortedGroups[focusedGroupIndex], at: focusedGroupIndex)
        AccessibilityNotification.announcement.post(argument: label)
    }
    
    private func toggleSelection(for group: DuplicateGroup) {
        guard viewModel.config.bulkActions else { return }
        
        let allSelected = group.tabs.allSatisfy { viewModel.selectedTabIds.contains($0.id) }
        
        if allSelected {
            for tab in group.tabs {
                viewModel.selectedTabIds.remove(tab.id)
            }
        } else {
            for tab in group.tabs {
                viewModel.selectedTabIds.insert(tab.id)
            }
        }
    }
    
    private func deselectAll() {
        viewModel.selectedTabIds.removeAll()
        AccessibilityNotification.announcement.post(argument: "Selection cleared")
    }

    private func applyRangeSelection(to newIndex: Int) {
        guard viewModel.config.bulkActions else { return }

        let anchor = selectionAnchor ?? focusedGroupIndex
        selectionAnchor = anchor

        let start = min(anchor, newIndex)
        let end = max(anchor, newIndex)

        for i in start...end {
            guard i < sortedGroups.count else { continue }
            let group = sortedGroups[i]
            if !group.tabs.allSatisfy({ viewModel.selectedTabIds.contains($0.id) }) {
                for tab in group.tabs {
                    viewModel.selectedTabIds.insert(tab.id)
                }
            }
        }

        focusedGroupIndex = newIndex

        let count = end - start + 1
        AccessibilityNotification.announcement.post(
            argument: "Selected \(count) row\(count == 1 ? "" : "s")"
        )
    }
    
    private func accessibilityLabel(for group: DuplicateGroup, at index: Int) -> String {
        let title = group.tabs.first?.title ?? "Untitled"
        let domain = group.tabs.first?.urlDomain ?? "unknown domain"
        let count = group.tabs.count
        let position = index + 1
        let total = sortedGroups.count
        let selected = isSelected(group) ? ", selected" : ", not selected"
        
        return "\(title), \(domain), \(count) duplicates\(selected), \(position) of \(total)"
    }
}

struct TableRow: View {
    let group: DuplicateGroup
    @ObservedObject var viewModel: TabManagerViewModel
    let isFocused: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Title
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                
                Text(group.tabs.first?.title ?? "Untitled")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 300, alignment: .leading)
            
            // Domain
            Text(group.tabs.first?.urlDomain ?? "-")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)
            
            // Window
            Text("\(group.tabs.first?.windowId ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Count
            HStack(spacing: 4) {
                Text("\(group.tabs.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if group.tabs.count > 1 {
                    Text("(wasted: \(group.tabs.count - 1))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // Age
            Text(formatAge(group.tabs.first?.openedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    if let firstTab = group.tabs.first {
                        Task {
                            await viewModel.activateTab(firstTab)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Activate tab")
                .opacity(isHovered ? 1 : 0)
                
                if viewModel.config.bulkActions {
                    let allSelected = group.tabs.allSatisfy { viewModel.selectedTabIds.contains($0.id) }
                    Button {
                        for tab in group.tabs {
                            if allSelected {
                                viewModel.selectedTabIds.remove(tab.id)
                            } else {
                                viewModel.selectedTabIds.insert(tab.id)
                            }
                        }
                    } label: {
                        Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help(allSelected ? "Deselect all" : "Select all")
                }
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color(.selectedControlColor).opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatAge(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}

extension TabInfo {
    var urlDomain: String? {
        guard let url = URL(string: url) else { return nil }
        return url.host?.replacingOccurrences(of: "www.", with: "")
    }
}
