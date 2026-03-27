import Foundation
import Compression

/// Automatically saves closed tab URLs to a dated history file.
/// Users can browse and restore tabs from any date.
/// File operations run on background threads to avoid blocking UI (CONCURRENCY-007 Fix)
/// Archives are compressed using LZFSE algorithm for 50-90% size reduction (PERF-010)
final class AutoArchiveManager: @unchecked Sendable {
    static let shared = AutoArchiveManager()
    
    private let fileManager = FileManager.default
    private var archiveDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ChromeTabManager/History", isDirectory: true)
    }
    
    private let archiveExtension = "ctma"
    private let magicHeader = Data("CTMA".utf8)
    
    private init() {
        try? fileManager.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
    }
    
    /// Archive tabs that were closed.
    /// Runs on background thread to avoid blocking UI (CONCURRENCY-007 Fix)
    /// Data is compressed using LZFSE algorithm (PERF-010)
    func archiveClosedTabs(_ tabs: [TabInfo]) {
        guard !tabs.isEmpty else { return }
        
        let dateStr = dateString(for: Date())
        let fileURL = archiveDirectory.appendingPathComponent("\(dateStr).\(archiveExtension)")
        let content = generateMarkdown(for: tabs, date: Date())
        let directory = archiveDirectory
        
        Task(priority: .background) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            if let compressed = try? self.compress(content) {
                try? compressed.write(to: fileURL)
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
                .filter { $0.pathExtension == self.archiveExtension || $0.pathExtension == "md" }
                .compactMap { url -> ArchiveEntry? in
                    let name = url.deletingPathExtension().lastPathComponent
                    guard let date = self.dateFromString(name) else { return nil }
                    
                    let content = self.loadArchiveContent(from: url)
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
            guard let content = self.loadArchiveContent(from: url) else {
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
    
    /// Restore tabs from an archive by opening them in Chrome.
    /// Returns the count of successfully opened tabs.
    func restoreTabs(_ tabs: [ArchivedTab]) async -> Int {
        guard !tabs.isEmpty else { return 0 }
        guard await ChromeController.shared.isChromeRunning() else { return 0 }
        
        let windowCount = (try? await ChromeController.shared.getWindowCount()) ?? 0
        guard windowCount > 0 else { return 0 }
        
        var restoredCount = 0
        
        for tab in tabs {
            let success = await ChromeController.shared.openTab(windowId: 1, url: tab.url)
            if success {
                restoredCount += 1
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        return restoredCount
    }
    
    // MARK: - Compression (PERF-010)
    
    /// Compress string to LZFSE compressed Data
    private func compress(_ string: String) throws -> Data {
        guard let inputData = string.data(using: .utf8) else {
            throw CompressionError.encodingFailed
        }
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: inputData.count)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = inputData.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else { return 0 }
            return compression_encode_buffer(
                destinationBuffer,
                inputData.count,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                inputData.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        
        guard compressedSize > 0 else {
            throw CompressionError.compressionFailed
        }
        
        var result = Data()
        result.append(magicHeader)
        var size = UInt32(compressedSize).bigEndian
        result.append(Data(bytes: &size, count: 4))
        result.append(destinationBuffer, count: compressedSize)
        
        return result
    }
    
    /// Decompress LZFSE compressed Data to String
    private func decompress(_ data: Data) -> String? {
        guard data.count > 8 else { return nil }
        
        let header = data.prefix(4)
        guard header == magicHeader else {
            return String(data: data, encoding: .utf8)
        }
        
        let compressedSize = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let compressedData = data.subdata(in: 8..<(8 + Int(compressedSize)))
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 10)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = compressedData.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer,
                compressedData.count * 10,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                compressedData.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        
        guard decompressedSize > 0 else { return nil }
        
        let resultData = Data(bytes: UnsafeRawPointer(destinationBuffer), count: decompressedSize)
        return String(data: resultData, encoding: .utf8)
    }
    
    /// Load archive content (handles both compressed and uncompressed formats)
    private func loadArchiveContent(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        if url.pathExtension == archiveExtension {
            return decompress(data)
        } else {
            return String(data: data, encoding: .utf8)
        }
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
}

// MARK: - Errors

enum CompressionError: Error {
    case encodingFailed
    case compressionFailed
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
