import Foundation
import os.log

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "ChromeTabManager"

    static let general = os.Logger(subsystem: subsystem, category: "general")
    static let network = os.Logger(subsystem: subsystem, category: "network")
    static let security = os.Logger(subsystem: subsystem, category: "security")
    static let retry = os.Logger(subsystem: subsystem, category: "retry")
}

enum SecureLogger {
    static func debug(_ message: String) {
        #if DEBUG
        Logger.general.debug("\(message)")
        #endif
    }

    static func info(_ message: String) {
        Logger.general.info("\(message)")
    }

    static func warning(_ message: String) {
        Logger.general.warning("\(message)")
    }

    static func error(_ message: String) {
        Logger.general.error("\(message)")
    }
}
