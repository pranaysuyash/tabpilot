import SwiftUI

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
