import SwiftUI

/// Shows a health score gauge and breakdown for the current tab set.
struct TabDebtView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    @State private var stats: TabStatistics?
    
    var body: some View {
        if let metrics = viewModel.healthMetrics {
            VStack(spacing: 16) {
                // Circular score gauge
                ScoreGaugeView(score: metrics.score, color: metrics.statusColor)
                
                // Label
                Text(healthLabel(for: metrics.score))
                    .font(.headline)
                    .foregroundStyle(metrics.statusColor)
                    .accessibilityLabel("Health status: \(healthLabel(for: metrics.score))")
                
                // Tab Debt Trend (P3)
                if let stats = stats, stats.tabDebtHistory.count >= 2 {
                    DebtTrendView(stats: stats)
                }
                
                Divider()

                // Stat rows
                VStack(spacing: 8) {
                    TabDebtStatRow(
                        icon: "doc.on.doc.fill",
                        label: "Duplicates",
                        value: "\(metrics.duplicateCount)",
                        color: metrics.duplicateCount > 0 ? .orange : .green
                    )
                    TabDebtStatRow(
                        icon: "rectangle.stack.fill",
                        label: "Total Tabs",
                        value: "\(metrics.totalTabs)",
                        color: .blue
                    )
                    TabDebtStatRow(
                        icon: "uiwindow.split.2x1",
                        label: "Avg per Window",
                        value: String(format: "%.1f", metrics.averageTabsPerWindow),
                        color: .purple
                    )
                    TabDebtStatRow(
                        icon: "clock.fill",
                        label: "Oldest Tab",
                        value: humanAge(metrics.oldestTabAge),
                        color: ageColor(metrics.oldestTabAge)
                    )
                }
            }
            .padding()
            .frame(maxWidth: 300)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tab health score: \(metrics.score) out of 100, \(healthLabel(for: metrics.score))")
            .onAppear {
                stats = StatisticsStore.shared.getStats()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Scan first to see your tab health score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 300)
            .padding()
            .accessibilityLabel("Tab health score not yet available. Run a scan first.")
        }
    }

    private func healthLabel(for score: Int) -> String {
        switch score {
        case 80...: return "Excellent"
        case 50...: return "Fair"
        default:    return "Needs Cleanup"
        }
    }

    private func humanAge(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        let days = Int(seconds / 86400)
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func ageColor(_ seconds: TimeInterval) -> Color {
        if seconds >= 86400 * 7 { return .red }
        if seconds >= 86400 { return .orange }
        return .green
    }
}

/// Custom arc-based circular gauge showing 0-100 score (macOS 13 compatible).
private struct ScoreGaugeView: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            // Track arc
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Fill arc
            Circle()
                .trim(from: 0, to: 0.75 * CGFloat(score) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(.easeOut(duration: 0.6), value: score)

            // Score number
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ 100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
        .accessibilityLabel("Health score \(score) out of 100")
        .accessibilityValue("\(score)")
    }
}

private struct TabDebtStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Shows tab debt trend over time (P3 Feature)
struct DebtTrendView: View {
    let stats: TabStatistics
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stats.debtTrend.icon)
                .foregroundStyle(trendColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Debt Trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stats.debtTrend.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(trendColor)
            }
            
            Spacer()
            
            if !stats.tabDebtHistory.isEmpty {
                let last = stats.tabDebtHistory.last!
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(last.duplicateCount) dups")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(trendColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var trendColor: Color {
        switch stats.debtTrend {
        case .improving: return .green
        case .worsening: return .red
        case .stable: return .orange
        }
    }
}
