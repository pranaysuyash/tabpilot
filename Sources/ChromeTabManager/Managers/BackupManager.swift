import Foundation

actor BackupManager {
    static let shared = BackupManager()
    
    private let fileManager = FileManager.default
    private let maxBackups = 5
    private let schemaVersion = "1.0"
    
    private nonisolated var backupDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ChromeTabManager/Backups", isDirectory: true)
    }
    
    init() {
        createBackupDirectoryIfNeeded()
    }
    
    private func createBackupDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }
    }
    
    struct Backup: Identifiable, Codable, Sendable {
        let id: UUID
        let timestamp: Date
        let version: String
        let size: Int64
    }
    
    struct BackupMetadata: Codable, Sendable {
        let id: UUID
        let timestamp: Date
        let version: String
        let tabCount: Int
        let archiveCount: Int
    }
    
    enum BackupError: LocalizedError {
        case backupCreationFailed
        case invalidBackup
        case restoreFailed(underlying: Error)
        case cleanupFailed
        
        var errorDescription: String? {
            switch self {
            case .backupCreationFailed:
                return "Failed to create backup"
            case .invalidBackup:
                return "Backup file is invalid"
            case .restoreFailed(let error):
                return "Restore failed: \(error.localizedDescription)"
            case .cleanupFailed:
                return "Failed to cleanup old backups"
            }
        }
    }
    
    struct BackupData: Codable, Sendable {
        let metadata: BackupMetadata
        let tabHistory: [TabInfoBackup]
        let archives: [ArchiveInfoBackup]
    }
    
    func createBackup(tabHistory: [TabInfo], archives: [ArchiveInfo]) async throws -> Backup {
        let backupId = UUID()
        let timestamp = Date()
        
        let metadata = BackupMetadata(
            id: backupId,
            timestamp: timestamp,
            version: schemaVersion,
            tabCount: tabHistory.count,
            archiveCount: archives.count
        )
        
        let tabHistoryBackup = tabHistory.map { TabInfoBackup(from: $0) }
        let archivesBackup = archives.map { ArchiveInfoBackup(from: $0) }
        
        let backupData = BackupData(
            metadata: metadata,
            tabHistory: tabHistoryBackup,
            archives: archivesBackup
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(backupData)
        
        let backupURL = backupDirectory.appendingPathComponent("\(backupId.uuidString).backup")
        try jsonData.write(to: backupURL)
        
        let metadataURL = backupDirectory.appendingPathComponent("\(backupId.uuidString).metadata.json")
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL)
        
        try await cleanupOldBackups()
        
        SecureLogger.info("Created backup: \(backupId.uuidString), size: \(jsonData.count) bytes")
        
        return Backup(
            id: backupId,
            timestamp: timestamp,
            version: schemaVersion,
            size: Int64(jsonData.count)
        )
    }
    
    func restore(from backup: Backup) async throws {
        let backupURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw BackupError.invalidBackup
        }
        
        let data = try Data(contentsOf: backupURL)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let backupData = try? decoder.decode(BackupData.self, from: data) else {
            throw BackupError.invalidBackup
        }
        
        guard backupData.metadata.version == schemaVersion else {
            throw BackupError.invalidBackup
        }
        
        let tabs = backupData.tabHistory.map { $0.toTabInfo() }
        try await restoreTabs(from: tabs)
        try await restoreArchives(from: backupData.archives.map { $0.toArchiveInfo() })
        
        SecureLogger.info("Restored backup: \(backup.id.uuidString)")
    }
    
    func restoreTabs(from tabs: [TabInfo]) async throws {
        // Restore tabs to ClosedTabHistoryStore
    }
    
    func restoreArchives(from archives: [ArchiveInfo]) async throws {
        // Restore archives to ArchiveManager
    }
    
    func listBackups() -> [Backup] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else {
            return []
        }
        
        let backups = contents.compactMap { url -> Backup? in
            guard url.pathExtension == "backup" else { return nil }
            
            let metadataURL = url.deletingPathExtension().appendingPathExtension("metadata.json")
            guard let metadataData = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONDecoder().decode(BackupMetadata.self, from: metadataData) else {
                return nil
            }
            
            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            
            return Backup(
                id: metadata.id,
                timestamp: metadata.timestamp,
                version: metadata.version,
                size: size
            )
        }
        
        return backups.sorted { $0.timestamp > $1.timestamp }
    }
    
    func deleteBackup(_ backup: Backup) throws {
        let backupURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).backup")
        let metadataURL = backupDirectory.appendingPathComponent("\(backup.id.uuidString).metadata.json")
        
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.removeItem(at: metadataURL)
    }
    
    private func cleanupOldBackups() async throws {
        let backups = listBackups()
        
        if backups.count > maxBackups {
            let toDelete = backups.suffix(from: maxBackups)
            
            for backup in toDelete {
                try? deleteBackup(backup)
            }
        }
    }
}

struct TabInfoBackup: Codable, Sendable {
    let id: String
    let windowId: Int
    let tabIndex: Int
    let title: String
    let url: String
    let openedAt: Date
    
    init(from tabInfo: TabInfo) {
        self.id = tabInfo.id
        self.windowId = tabInfo.windowId
        self.tabIndex = tabInfo.tabIndex
        self.title = tabInfo.title
        self.url = tabInfo.url
        self.openedAt = tabInfo.openedAt
    }
    
    func toTabInfo() -> TabInfo {
        TabInfo(
            id: id,
            windowId: windowId,
            tabIndex: tabIndex,
            title: title,
            url: url,
            openedAt: openedAt
        )
    }
}

struct ArchiveInfoBackup: Codable, Sendable {
    let id: UUID
    let name: String
    let tabCount: Int
    let createdAt: Date
    let urlPath: String?
    
    init(from archiveInfo: ArchiveInfo) {
        self.id = archiveInfo.id
        self.name = archiveInfo.name
        self.tabCount = archiveInfo.tabCount
        self.createdAt = archiveInfo.createdAt
        self.urlPath = archiveInfo.url?.path
    }
    
    func toArchiveInfo() -> ArchiveInfo {
        ArchiveInfo(
            id: id,
            name: name,
            tabCount: tabCount,
            createdAt: createdAt,
            url: urlPath.flatMap { URL(fileURLWithPath: $0) }
        )
    }
}

struct ArchiveInfo: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let tabCount: Int
    let createdAt: Date
    let url: URL?
}
