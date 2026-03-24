import Foundation
import AppKit

/// Exports tab data in various formats (Markdown, CSV, JSON) to the file system or clipboard.
struct ExportManager {
    
    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown"
        case csv = "CSV"
        case json = "JSON"
        
        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .csv: return "csv"
            case .json: return "json"
            }
        }
    }
    
    // MARK: - Export Methods
    
    static func export(tabs: [TabInfo], format: ExportFormat) -> String {
        switch format {
        case .markdown: return exportMarkdown(tabs: tabs)
        case .csv: return exportCSV(tabs: tabs)
        case .json: return exportJSON(tabs: tabs)
        }
    }
    
    static func exportDuplicates(groups: [DuplicateGroup], format: ExportFormat) -> String {
        switch format {
        case .markdown: return exportDuplicatesMarkdown(groups: groups)
        case .csv: return exportDuplicatesCSV(groups: groups)
        case .json: return exportDuplicatesJSON(groups: groups)
        }
    }
    
    // MARK: - Markdown
    
    private static func exportMarkdown(tabs: [TabInfo]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var md = "# Chrome Tabs — \(dateFormatter.string(from: Date()))\n\n"
        md += "> \(tabs.count) tabs across \(Set(tabs.map(\.windowId)).count) windows\n\n"
        
        let byDomain = Dictionary(grouping: tabs) { $0.domain }
        for (domain, domainTabs) in byDomain.sorted(by: { $0.value.count > $1.value.count }) {
            md += "## \(domain) (\(domainTabs.count))\n\n"
            for tab in domainTabs {
                let title = tab.title.replacingOccurrences(of: "]", with: "\\]")
                md += "- [\(title)](\(tab.url))\n"
            }
            md += "\n"
        }
        return md
    }
    
    private static func exportDuplicatesMarkdown(groups: [DuplicateGroup]) -> String {
        var md = "# Duplicate Tabs Report\n\n"
        for group in groups {
            md += "## \(group.tabs.first?.title ?? group.displayUrl) (×\(group.tabs.count))\n"
            md += "> `\(group.displayUrl)`\n\n"
        }
        return md
    }
    
    // MARK: - CSV
    
    private static func exportCSV(tabs: [TabInfo]) -> String {
        var csv = "Title,URL,Domain,Window,Tab,Age\n"
        for tab in tabs {
            let title = tab.title.replacingOccurrences(of: "\"", with: "\"\"")
            let url = tab.url.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(title)\",\"\(url)\",\"\(tab.domain)\",\(tab.windowId),\(tab.tabIndex),\"\(tab.ageDescription)\"\n"
        }
        return csv
    }
    
    private static func exportDuplicatesCSV(groups: [DuplicateGroup]) -> String {
        var csv = "Group,Title,URL\n"
        for (i, group) in groups.enumerated() {
            csv += "\(i+1),\"\(group.tabs.first?.title ?? "")\",\"\(group.displayUrl)\"\n"
        }
        return csv
    }
    
    // MARK: - JSON
    
    private static func exportJSON(tabs: [TabInfo]) -> String {
        let exportData = tabs.map { ["title": $0.title, "url": $0.url, "domain": $0.domain] }
        guard let data = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .withoutEscapingSlashes]),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }
    
    private static func exportDuplicatesJSON(groups: [DuplicateGroup]) -> String {
        let exportData = groups.map { ["url": $0.displayUrl, "count": $0.tabs.count] as [String : Any] }
        guard let data = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .withoutEscapingSlashes]),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }
}
