import Foundation

/// Encapsulates a single tab-close operation with retry and validation logic.
struct TabCloseOperation: Sendable {
    let windowId: Int
    let url: String
    let title: String
    let targetIndex: Int
    
    enum Result {
        case success
        case failed(String)
        case ambiguous
        case notFound
    }
    
    /// Execute the close operation via AppleScript
    func execute() async -> Result {
        let script = """
        tell application "Google Chrome"
            close tab \(targetIndex) of window \(windowId)
            return "closed"
        end tell
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if task.terminationStatus == 0 && output == "closed" {
                return .success
            } else {
                return .failed(output)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

/// Batch tab close state tracker for deterministic close sequences.
struct TabCloseBatch {
    var operations: [TabCloseOperation]
    var closed: Int = 0
    var failed: Int = 0
    var ambiguous: Int = 0
    var skipped: Int = 0
    
    var totalAttempted: Int { closed + failed + ambiguous + skipped }
    var successRate: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(closed) / Double(totalAttempted)
    }
}
