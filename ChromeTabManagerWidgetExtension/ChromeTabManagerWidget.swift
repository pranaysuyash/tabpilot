import WidgetKit
import SwiftUI

struct ChromeTabWidgetEntry: TimelineEntry {
    let date: Date
    let totalTabs: Int
    let duplicateGroups: Int
    let wastedTabs: Int
    let windows: Int
}

struct ChromeTabWidgetProvider: TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.pranay.chrometabmanager")

    func placeholder(in context: Context) -> ChromeTabWidgetEntry {
        ChromeTabWidgetEntry(date: Date(), totalTabs: 42, duplicateGroups: 8, wastedTabs: 15, windows: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChromeTabWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChromeTabWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> ChromeTabWidgetEntry {
        ChromeTabWidgetEntry(
            date: Date(),
            totalTabs: sharedDefaults?.integer(forKey: "widget.totalTabs") ?? 0,
            duplicateGroups: sharedDefaults?.integer(forKey: "widget.duplicateGroups") ?? 0,
            wastedTabs: sharedDefaults?.integer(forKey: "widget.wastedTabs") ?? 0,
            windows: sharedDefaults?.integer(forKey: "widget.windows") ?? 0
        )
    }
}

struct ChromeTabManagerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ChromeTabWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                Text("Chrome Tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.totalTabs)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(entry.duplicateGroups > 0 ? "\(entry.duplicateGroups) duplicate groups" : "No duplicates")
                    .font(.caption2)
                    .foregroundStyle(entry.duplicateGroups > 0 ? .orange : .green)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)

        default:
            VStack(alignment: .leading, spacing: 10) {
                Text("Chrome Tab Manager")
                    .font(.headline)

                HStack(spacing: 12) {
                    metric("Tabs", value: entry.totalTabs, color: .blue)
                    metric("Dupes", value: entry.duplicateGroups, color: .orange)
                    metric("Wasted", value: entry.wastedTabs, color: .red)
                    metric("Windows", value: entry.windows, color: .purple)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        }
    }

    private func metric(_ title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

struct ChromeTabManagerWidget: Widget {
    let kind: String = "ChromeTabManagerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChromeTabWidgetProvider()) { entry in
            ChromeTabManagerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chrome Tab Manager")
        .description("Shows tab count and duplicate health at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
