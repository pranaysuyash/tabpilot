#!/usr/bin/env swift
// TabTimeHost — Native Messaging Host for TabPilot
// Receives tab timing data from the Chrome extension via stdin (length-prefixed JSON)
// and writes it to a shared JSON file that the main TabPilot app can read.
//
// Chrome Native Messaging protocol:
//   - Messages are preceded by a 4-byte little-endian length header
//   - JSON payload follows the length header
//   - Host reads from stdin, writes responses to stdout

import Foundation
import TabTimeShared

// ── Configuration ────────────────────────────────────────────────

let dataFile: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = appSupport.appendingPathComponent("TabPilot", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("tab_time_data.json")
}()

// ── Native Messaging Protocol ────────────────────────────────────

func readMessage() -> [String: Any]? {
    let stdin = FileHandle.standardInput

    // Read 4-byte length header
    guard let lengthData = stdin.readData(ofLength: 4) as Data?, lengthData.count == 4 else {
        return nil
    }

    let length = lengthData.withUnsafeBytes {
        UInt32(littleEndian: $0.load(as: UInt32.self))
    }

    guard length > 0 && length < 10_485_760 else { // Max 10MB
        return nil
    }

    guard let jsonData = stdin.readData(ofLength: Int(length)) as Data?,
          jsonData.count == Int(length) else {
        return nil
    }

    return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
}

func writeMessage(_ dict: [String: Any]) {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else { return }

    let length = UInt32(jsonData.count)
    var lengthLE = length.littleEndian
    let lengthData = Data(bytes: &lengthLE, count: 4)

    let stdout = FileHandle.standardOutput
    stdout.write(lengthData)
    stdout.write(jsonData)
}

// ── Data Persistence ─────────────────────────────────────────────

func loadExisting() -> TabTimeData {
    guard let data = try? Data(contentsOf: dataFile),
          let decoded = try? JSONDecoder().decode(TabTimeData.self, from: data) else {
        return TabTimeData(lastUpdated: 0, date: "", domainTime: [:], tabDetails: [:])
    }
    return decoded
}

func save(_ tabTimeData: TabTimeData) {
    guard let data = try? JSONEncoder().encode(tabTimeData) else { return }
    try? data.write(to: dataFile, options: .atomic)
}

func normalizedURLKey(_ urlString: String) -> String {
    let trimmed = urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return trimmed.components(separatedBy: "?").first ?? trimmed
}

// ── Message Handling ─────────────────────────────────────────────

func handleMessage(_ message: [String: Any]) {
    guard let type = message["type"] as? String else { return }

    switch type {
    case "tab_time_update":
        handleTabTimeUpdate(message)
    case "ping":
        writeMessage(["type": "pong"])
    default:
        break
    }
}

func handleTabTimeUpdate(_ message: [String: Any]) {
    let date = message["date"] as? String ?? ""
    let timestamp = message["timestamp"] as? Double ?? 0

    // Parse domain time
    var newDomainTime: [String: Double] = [:]
    if let dt = message["domainTime"] as? [String: Any] {
        for (domain, ms) in dt {
            if let msVal = ms as? Double {
                newDomainTime[domain] = msVal
            } else if let msVal = ms as? Int {
                newDomainTime[domain] = Double(msVal)
            }
        }
    }

    // Parse tab details
    var newTabDetails: [String: TabTimeData.TabDetail] = [:]
    if let tabs = message["tabs"] as? [String: Any] {
        for (_, tabInfo) in tabs {
            if let info = tabInfo as? [String: Any],
               let url = info["url"] as? String,
               let domain = info["domain"] as? String {
                let totalMs: Double
                if let ms = info["totalMs"] as? Double {
                    totalMs = ms
                } else if let ms = info["totalMs"] as? Int {
                    totalMs = Double(ms)
                } else {
                    totalMs = 0
                }
                let urlKey = normalizedURLKey(url)
                let existingMs = newTabDetails[urlKey]?.totalMs ?? 0
                newTabDetails[urlKey] = TabTimeData.TabDetail(url: urlKey, domain: domain, totalMs: max(existingMs, totalMs))
            }
        }
    }

    // Merge with existing data (keep today's data, replace if new day)
    var existing = loadExisting()
    if existing.date != date {
        existing = TabTimeData(lastUpdated: timestamp, date: date, domainTime: newDomainTime, tabDetails: newTabDetails)
    } else {
        // Merge: take the max of each domain's time (extension sends cumulative)
        for (domain, ms) in newDomainTime {
            existing.domainTime[domain] = max(existing.domainTime[domain] ?? 0, ms)
        }
        existing.tabDetails = newTabDetails
        existing.lastUpdated = timestamp
    }

    save(existing)
}

// ── Main Loop ───────────────────────────────────────────────────

// Keep reading messages until stdin closes
while let message = readMessage() {
    handleMessage(message)
}
