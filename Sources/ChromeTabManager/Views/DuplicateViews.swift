import SwiftUI

struct DuplicateGroupSection: View {
    let group: DuplicateGroup
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                headerView
                Divider()
                actionButtons
                Divider()
                tabsListView
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duplicate group: \(group.tabs.first?.title ?? "Untitled"), \(group.tabs.count) copies")
    }
    
    private var headerView: some View {
        HStack {
            titleStack
            Spacer()
            copiesBadge
        }
    }
    
    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.tabs.first?.title.prefix(60) ?? "Untitled")
                .font(.headline)
                .lineLimit(1)
            
            Text(group.displayUrl.prefix(80))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    private var copiesBadge: some View {
        Text("\(group.tabs.count) copies")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red)
            .clipShape(Capsule())
            .accessibilityLabel("\(group.tabs.count) duplicate copies of this tab")
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            keepFirstButton
            keepLastButton
            Spacer()
        }
    }
    
    private var keepFirstButton: some View {
        ActionButton(title: "Keep First Seen", icon: "1.circle.fill", color: .green) {
            viewModel.selectAllExceptOldest(in: group)
        }
    }
    
    private var keepLastButton: some View {
        ActionButton(title: "Keep Last Seen", icon: "star.circle.fill", color: .blue) {
            viewModel.selectAllExceptNewest(in: group)
        }
    }
    
    private var tabsListView: some View {
        TabsListForDuplicateGroup(
            group: group,
            selectedTabIds: viewModel.selectedTabIds,
            showAge: viewModel.config.showAge,
            onToggle: { (tab: TabInfo) in viewModel.toggleSelection(for: tab.id) },
            onActivate: { (tab: TabInfo) in await viewModel.activateTab(tab) }
        )
    }
}

struct TabsListForDuplicateGroup: View {
    let group: DuplicateGroup
    let selectedTabIds: Set<String>
    let showAge: Bool
    let onToggle: (TabInfo) -> Void
    let onActivate: (TabInfo) async -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(group.tabs) { tab in
                TabRow(
                    tab: tab,
                    isOldest: tab.id == group.oldestTab?.id,
                    isNewest: tab.id == group.newestTab?.id,
                    isSelected: selectedTabIds.contains(tab.id),
                    showAge: showAge,
                    onToggle: { onToggle(tab) },
                    onFocus: { await onActivate(tab) }
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: group.tabs.map(\.id))
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
            titleAndUrl
            Spacer()
            windowsLabel
            copiesBadge
            keepOldestButton
            focusButton
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.tabs.first?.title ?? "Unknown"), \(group.tabs.count) duplicate copies")
        .accessibilityHint("Use action buttons to select tabs for cleanup")
    }
    
    private var titleAndUrl: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.tabs.first?.title ?? "Unknown")
                .font(.subheadline)
                .lineLimit(1)
            Text(group.displayUrl)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    private var windowsLabel: some View {
        let windows = Set(group.tabs.map { $0.windowId }).sorted()
        return Text("W\(windows.map(String.init).joined(separator: ","))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Windows: \(windows.map(String.init).joined(separator: ", "))")
    }
    
    private var copiesBadge: some View {
        Text("\(group.tabs.count)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
            .accessibilityLabel("\(group.tabs.count) duplicate copies")
    }
    
    private var keepOldestButton: some View {
        Button {
            viewModel.selectAllExceptOldest(in: group)
        } label: {
            Image(systemName: "1.circle.fill")
                .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
        .help("Keep first seen")
        .accessibilityLabel("Keep first seen tab")
        .accessibilityHint("Selects all copies except the oldest one for this URL")
    }
    
    private var focusButton: some View {
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
        .accessibilityLabel("Focus tab in Chrome")
        .accessibilityHint("Switches to this tab in Chrome")
    }
}
