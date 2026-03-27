import Foundation
import AppKit
import UniformTypeIdentifiers

/// Errors that can occur during export operations
enum ExportError: Error, LocalizedError {
    case noDataAvailable
    case fileSaveFailed
    case encodingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No time tracking data available for the selected period."
        case .fileSaveFailed:
            return "Failed to save the file. Please try a different location."
        case .encodingFailed:
            return "Failed to encode the data. Please try again."
        case .permissionDenied:
            return "Permission denied. Please grant access to the selected folder."
        }
    }
}

/// Exports tab data in various formats (Markdown, CSV, JSON) to the file system or clipboard.
struct ExportManager {
    
    enum TabExportFormat: String, CaseIterable {
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
    
    /// Export format for historical time data
    enum HistoryExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .json: return .json
            }
        }
    }
    
    /// Date range options for export
    enum ExportDateRange: String, CaseIterable {
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case last90Days = "Last 90 Days"
        
        var days: Int {
            switch self {
            case .last7Days: return 7
            case .last30Days: return 30
            case .last90Days: return 90
            }
        }
    }
    
    // MARK: - Tab Export Methods
    
    static func export(tabs: [TabInfo], format: TabExportFormat) -> String {
        switch format {
        case .markdown: return exportMarkdown(tabs: tabs)
        case .csv: return exportCSV(tabs: tabs)
        case .json: return exportJSON(tabs: tabs)
        }
    }
    
    static func exportDuplicates(groups: [DuplicateGroup], format: TabExportFormat) -> String {
        switch format {
        case .markdown: return exportDuplicatesMarkdown(groups: groups)
        case .csv: return exportDuplicatesCSV(groups: groups)
        case .json: return exportDuplicatesJSON(groups: groups)
        }
    }
    
    // MARK: - Historical Data Export
    
    /// Export historical time tracking data
    @MainActor
    static func exportHistory(format: HistoryExportFormat, days: Int) async throws {
        // Check if data is available
        let hasData = await TabTimeStore.shared.availableHistoryDays > 0
        guard hasData else {
            throw ExportError.noDataAvailable
        }
        
        // Generate export data
        let data: Data
        let filename: String
        
        switch format {
        case .csv:
            let csvString = await TabTimeStore.shared.exportToCSV(days: days)
            guard let csvData = csvString.data(using: .utf8) else {
                throw ExportError.encodingFailed
            }
            data = csvData
            filename = "tabpilot_history_\(formatDateForFilename()).csv"
        case .json:
            data = try await TabTimeStore.shared.exportToJSON(days: days)
            filename = "tabpilot_history_\(formatDateForFilename()).json"
        }
        
        // Present save dialog
        try await saveDataWithDialog(data: data, filename: filename, contentType: format.contentType)
    }
    
    /// Present save dialog and save data to user-selected location
    @MainActor
    private static func saveDataWithDialog(data: Data, filename: String, contentType: UTType) async throws {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [contentType]
        savePanel.canCreateDirectories = true
        
        let response = await withCheckedContinuation { continuation in
            savePanel.begin { result in
                continuation.resume(returning: result)
            }
        }
        
        guard response == .OK, let url = savePanel.url else {
            return // User cancelled
        }
        
        do {
            try data.write(to: url)
        } catch {
            if (error as NSError).code == 513 {
                throw ExportError.permissionDenied
            } else {
                throw ExportError.fileSaveFailed
            }
        }
    }
    
    private static func formatDateForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
