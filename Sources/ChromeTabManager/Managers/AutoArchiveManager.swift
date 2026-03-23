import Foundation

/// Automatically saves closed tab URLs to a dated history file.
/// Users can browse and restore tabs from any date.
/// File operations run on background threads to avoid blocking UI (CONCURRENCY-007 Fix)
final class AutoArchiveManager: @unchecked Sendable {
    static let shared = AutoArchiveManager()
    
    private let fileManager = FileManager.default
    private var archiveDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ChromeTabManager/History", isDirectory: true)
    }
    
    private init() {
        try? fileManager.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
    }
    
    /// Archive tabs that were closed.
    /// Runs on background thread to avoid blocking UI (CONCURRENCY-007 Fix)
    func archiveClosedTabs(_ tabs: [TabInfo]) {
        guard !tabs.isEmpty else { return }
        
        let dateStr = dateString(for: Date())
        let fileURL = archiveDirectory.appendingPathComponent("\(dateStr).md")
        let content = generateMarkdown(for: tabs, date: Date())
        let directory = archiveDirectory
        
        Task(priority: .background) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                self.appendToFile(content, at: fileURL)
            } else {
                try? content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    /// Get list of available archive dates asynchronously.
    /// Runs on background thread to avoid blocking UI (CONCURRENCY-007 Fix)
    func availableArchives() async -> [ArchiveEntry] {
        let directory = archiveDirectory
        
        return await Task(priority: .background) {
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
                return []
            }
            
            return files
                .filter { $0.pathExtension == "md" && !$0.lastPathComponent.hasPrefix("snapshot_") }
                .compactMap { url -> ArchiveEntry? in
                    let name = url.deletingPathExtension().lastPathComponent
                    guard let date = self.dateFromString(name) else { return nil }
                    
                    let content = try? String(contentsOf: url, encoding: .utf8)
                    let tabCount = content?.components(separatedBy: "- [").count ?? 0
                    
                    return ArchiveEntry(date: date, fileURL: url, tabCount: max(0, tabCount - 1))
                }
                .sorted { $0.date > $1.date }
        }.value
    }
    
    /// Load tabs from a specific archive asynchronously.
    /// Runs on background thread to avoid blocking UI (CONCURRENCY-007 Fix)
    func loadArchive(from url: URL) async -> [ArchivedTab] {
        await Task(priority: .background) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return []
            }
            
            var tabs: [ArchivedTab] = []
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                if line.hasPrefix("- [") {
                    let trimmed = line.dropFirst(3)
                    if let closeBracket = trimmed.firstIndex(of: "]"),
                       let openParen = trimmed.firstIndex(of: "("),
                       trimmed.lastIndex(of: ")") != nil {
                        let title = String(trimmed[..<closeBracket])
                        let url = String(trimmed[openParen...].dropFirst().dropLast())
                        tabs.append(ArchivedTab(title: title, url: url))
                    }
                }
            }
            
            return tabs
        }.value
    }
    
    // MARK: - Private Helpers
    
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func dateFromString(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
    
    private func generateMarkdown(for tabs: [TabInfo], date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var content = "\n\n## Closed at \(formatter.string(from: date))\n\n"
        let byDomain = Dictionary(grouping: tabs) { $0.domain }
        
        for (domain, domainTabs) in byDomain.sorted(by: { $0.value.count > $1.value.count }) {
            content += "### \(domain) (\(domainTabs.count))\n\n"
            for tab in domainTabs {
                let title = tab.title.replacingOccurrences(of: "]", with: "]")
                content += "- [\(title)](\(tab.url))\n"
            }
            content += "\n"
        }
        
        return content
    }
    
    private func appendToFile(_ content: String, at url: URL) {
        guard let data = content.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: url) else {
            return
        }
        
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }
}

// MARK: - Data Types

struct ArchiveEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let date: Date
    let fileURL: URL
    let tabCount: Int
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct ArchivedTab: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let url: String
}
