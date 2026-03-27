import SwiftUI

/// Displays active time for a tab with visual indicator
struct ActiveTimeBadge: View {
    let seconds: Double?
    var isMostActive: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            if let seconds = seconds {
                Image(systemName: isMostActive ? "flame.fill" : "clock")
                    .font(.caption2)
                    .foregroundStyle(isMostActive ? .orange : .secondary)
                
                Text(formatTime(seconds))
                    .font(.caption)
                    .foregroundStyle(isMostActive ? .orange : .secondary)
                    .fontWeight(isMostActive ? .medium : .regular)
            } else {
                Image(systemName: "clock.badge.questionmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.5))
                
                Text("Not tracked")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.5))
                    .italic()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            isMostActive 
                ? Color.orange.opacity(0.1) 
                : (seconds != nil ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .clipShape(Capsule())
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        if let seconds = seconds {
            let timeStr = formatTime(seconds)
            return isMostActive ? "Most active: \(timeStr)" : "Active \(timeStr)"
        } else {
            return "Active time not tracked"
        }
    }
    
    /// Format seconds into human-readable time string
    private func formatTime(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let totalHours = totalMinutes / 60
        
        if totalHours >= 1 {
            let minutes = totalMinutes % 60
            if minutes > 0 {
                return "\(totalHours)h \(minutes)m"
            } else {
                return "\(totalHours)h"
            }
        } else if totalMinutes >= 1 {
            return "\(totalMinutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }
}

/// Extension to TabInfo to add active time lookup
extension TabInfo {
    /// Gets the active time for this tab from TabTimeStore
    /// Returns time in seconds, or nil if not tracked
    var activeTimeSeconds: Double? {
        get async {
            await TabTimeStore.shared.timeForURL(self.url)
        }
    }
}

/// View modifier to add active time display to duplicate group tabs
struct PerTabActiveTimeView: View {
    let tabs: [TabInfo]
    let selectedTabIds: Set<String>
    let showAge: Bool
    let onToggle: (TabInfo) -> Void
    let onActivate: (TabInfo) async -> Void

    @State private var tabTimes: [String: Double] = [:]
    @State private var tabSparklineData: [String: [SparklineDataPoint]] = [:]
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 8) {
            ForEach(sortedTabs) { tab in
                TabRowWithActiveTime(
                    tab: tab,
                    activeTime: tabTimes[tab.url],
                    sparklineData: tabSparklineData[tab.url] ?? [],
                    isMostActive: isMostActive(tab),
                    isOldest: tab.id == oldestTab?.id,
                    isNewest: tab.id == newestTab?.id,
                    isSelected: selectedTabIds.contains(tab.id),
                    showAge: showAge,
                    onToggle: { onToggle(tab) },
                    onFocus: { await onActivate(tab) }
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: sortedTabs.map(\.id))
        .task {
            await loadTabTimes()
        }
    }
    
    /// Tabs sorted by active time (most active first)
    private var sortedTabs: [TabInfo] {
        tabs.sorted { tab1, tab2 in
            let time1 = tabTimes[tab1.url] ?? 0
            let time2 = tabTimes[tab2.url] ?? 0
            return time1 > time2
        }
    }
    
    private var oldestTab: TabInfo? {
        tabs.min { $0.openedAt < $1.openedAt }
    }
    
    private var newestTab: TabInfo? {
        tabs.max { $0.openedAt < $1.openedAt }
    }
    
    private func isMostActive(_ tab: TabInfo) -> Bool {
        guard let maxTime = tabTimes.values.max(), maxTime > 0 else { return false }
        return tabTimes[tab.url] == maxTime
    }
    
    private func loadTabTimes() async {
        isLoading = true
        defer { isLoading = false }
        
        var times: [String: Double] = [:]
        var sparklineData: [String: [SparklineDataPoint]] = [:]
        
        for tab in tabs {
            if let time = await TabTimeStore.shared.timeForURL(tab.url) {
                times[tab.url] = time
                
                // Load sparkline data for this URL
                let dailyData = await TabTimeStore.shared.getDailyTimeForURL(tab.url, days: 7)
                let sparklinePoints = dailyData.map { dayData in
                    SparklineDataPoint(
                        date: dayData.date,
                        value: dayData.seconds,
                        label: formatSparklineLabel(for: dayData.date)
                    )
                }
                sparklineData[tab.url] = sparklinePoints
            }
        }
        
        tabTimes = times
        tabSparklineData = sparklineData
    }
    
    private func formatSparklineLabel(for date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
}

/// Tab row variant that displays active time
struct TabRowWithActiveTime: View {
    let tab: TabInfo
    let activeTime: Double?
    let sparklineData: [SparklineDataPoint]
    let isMostActive: Bool
    let isOldest: Bool
    let isNewest: Bool
    let isSelected: Bool
    let showAge: Bool
    let onToggle: () -> Void
    let onFocus: () async -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: .init(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .accessibilityLabel("Select \(tab.title)")
            .accessibilityHint("Marks this tab for bulk close action")
            .accessibilityValue(isSelected ? "selected" : "not selected")
            
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
            .accessibilityLabel(isOldest ? "First seen tab" : isNewest ? "Last seen tab" : "")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("Window \(tab.windowId) • Tab \(tab.tabIndex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Sparkline showing 7-day trend (if data available)
            if !sparklineData.isEmpty && hasNonZeroData {
                SparklineView(
                    data: sparklineData,
                    height: 24,
                    showDots: true,
                    lineWidth: 1.5
                )
                .frame(width: 80)
                .help("7-day activity trend")
            }
            
            // Active time badge
            ActiveTimeBadge(seconds: activeTime, isMostActive: isMostActive)
            
            if showAge {
                Text(tab.ageDescription)
                    .font(.caption)
                    .foregroundStyle(ageColor)
                    .accessibilityLabel("Opened \(tab.ageDescription) ago")
            }
            
            Button {
                Task { await onFocus() }
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Focus tab in Chrome")
            .accessibilityLabel("Focus tab in Chrome")
            .accessibilityHint("Switches to this tab in Chrome")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityHint("Double-tap to toggle selection")
    }

    private var hasNonZeroData: Bool {
        sparklineData.contains { $0.value > 0 }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.secondary.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    private var accessibilityLabelText: String {
        let baseLabel = "\(tab.title), Window \(tab.windowId), Tab \(tab.tabIndex)"
        if isOldest {
            return baseLabel + ", first seen"
        } else if isNewest {
            return baseLabel + ", last seen"
        }
        return baseLabel
    }
    
    var ageColor: Color {
        let seconds = Date().timeIntervalSince(tab.openedAt)
        if seconds >= 86400 { return .red }
        if seconds >= 3600 { return .orange }
        return .green
    }
}

#Preview {
    VStack(spacing: 16) {
        ActiveTimeBadge(seconds: 3600, isMostActive: true)
        ActiveTimeBadge(seconds: 300)
        ActiveTimeBadge(seconds: nil)
    }
    .padding()
}
