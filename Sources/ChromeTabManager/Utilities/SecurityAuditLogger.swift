import Foundation
import CryptoKit

enum AuditSeverity: String, Codable {
    case info
    case warning
    case critical
}

struct SecurityAuditEvent: Codable {
    let id: String
    let timestamp: Date
    let category: String
    let action: String
    let severity: AuditSeverity
    let details: [String: String]
    let previousHash: String?
    let recordHash: String
    let signatureBase64: String?
}

actor SecurityAuditLogger {
    static let shared = SecurityAuditLogger()

    private let fileURL: URL
    private var previousHash: String?
    private let encoder: JSONEncoder

    init(fileURL: URL = SecurityAuditLogger.defaultFileURL()) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        prepareStore()
    }

    func log(
        category: String,
        action: String,
        severity: AuditSeverity = .info,
        details: [String: String] = [:],
        signEvent: Bool = true
    ) {
        let timestamp = Date()
        let canonical = Self.canonicalPayload(
            timestamp: timestamp,
            category: category,
            action: action,
            severity: severity,
            details: details,
            previousHash: previousHash
        )
        let hashHex = Self.sha256Hex(canonical)

        let signature: String?
        if signEvent {
            do {
                let sig = try SecureEnclaveKeyManager.sign(canonical)
                signature = sig.base64EncodedString()
            } catch {
                Logger.security.warning("Audit signature unavailable: \(error.localizedDescription)")
                signature = nil
            }
        } else {
            signature = nil
        }

        let event = SecurityAuditEvent(
            id: UUID().uuidString,
            timestamp: timestamp,
            category: category,
            action: action,
            severity: severity,
            details: details,
            previousHash: previousHash,
            recordHash: hashHex,
            signatureBase64: signature
        )

        do {
            let encoded = try encoder.encode(event)
            try appendLine(encoded)
            previousHash = hashHex
        } catch {
            Logger.security.error("Audit append failed: \(error.localizedDescription)")
        }
    }

    func logRuntimeReport(_ report: RuntimeSecurityReport) {
        log(
            category: "runtime",
            action: "startup_scan",
            severity: report.requiresMitigation ? .warning : .info,
            details: [
                "debuggerAttached": String(report.debuggerAttached),
                "suspiciousEnvironmentCount": String(report.suspiciousEnvironment.count),
                "suspiciousLibraryCount": String(report.suspiciousLibraries.count),
                "codeSignatureValid": String(report.codeSignatureValid),
                "keyProtectionMode": SecureEnclaveKeyManager.keyProtectionMode().rawValue
            ]
        )
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("ChromeTabManager", isDirectory: true)
            .appendingPathComponent("Security", isDirectory: true)
            .appendingPathComponent("audit.jsonl", isDirectory: false)
    }

    private func prepareStore() {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            previousHash = Self.extractLastHash(from: fileURL)
        } catch {
            Logger.security.error("Audit store initialization failed: \(error.localizedDescription)")
        }
    }

    private func appendLine(_ lineData: Data) throws {
        let newline = Data([0x0A])
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: lineData)
            try handle.write(contentsOf: newline)
            return
        }

        var data = lineData
        data.append(newline)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func canonicalPayload(
        timestamp: Date,
        category: String,
        action: String,
        severity: AuditSeverity,
        details: [String: String],
        previousHash: String?
    ) -> Data {
        let detailString = details
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")

        let payload = [
            "timestamp=\(ISO8601DateFormatter().string(from: timestamp))",
            "category=\(category)",
            "action=\(action)",
            "severity=\(severity.rawValue)",
            "details=\(detailString)",
            "previousHash=\(previousHash ?? "none")"
        ].joined(separator: "|")

        return Data(payload.utf8)
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func extractLastHash(from fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let lastLine = text.split(separator: "\n").last else { return nil }
        guard let json = lastLine.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SecurityAuditEvent.self, from: json))?.recordHash
    }
}
