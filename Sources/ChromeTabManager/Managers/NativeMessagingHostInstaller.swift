import Foundation

/// Manages automatic installation of the Chrome Native Messaging Host manifest.
/// This allows the browser extension to communicate with the native TabTimeHost executable.
@MainActor
final class NativeMessagingHostInstaller {
    
    // MARK: - Constants
    
    private static let hostName = "com.tabpilot.timetracker"
    private static let manifestFilename = "com.tabpilot.timetracker.json"
    private static let hostBinaryName = "TabTimeHost"
    private static let defaultExtensionOrigin = "chrome-extension://EXTENSION_ID_HERE/"
    
    /// Chrome's Native Messaging Hosts directory
    private static var chromeNativeMessagingDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts", isDirectory: true)
    }
    
    /// Destination path for the manifest file
    private static var manifestDestination: URL {
        chromeNativeMessagingDir.appendingPathComponent(manifestFilename)
    }
    
    // MARK: - Properties
    
    private let logger = Logger.general
    
    /// Shared instance for app-wide access
    static let shared = NativeMessagingHostInstaller()
    
    // MARK: - Installation Status
    
    /// Checks if the native messaging host is already installed and valid
    func isInstalled() -> Bool {
        let fileManager = FileManager.default
        
        // Check if manifest exists
        guard fileManager.fileExists(atPath: Self.manifestDestination.path) else {
            logger.debug("Native messaging host manifest not found at \(Self.manifestDestination.path)")
            return false
        }
        
        // Verify the manifest is readable and contains valid JSON
        guard let data = try? Data(contentsOf: Self.manifestDestination),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = manifest["name"] as? String,
              name == Self.hostName else {
            logger.warning("Native messaging host manifest exists but is invalid")
            return false
        }
        
        logger.debug("Native messaging host is installed and valid")
        return true
    }
    
    /// Returns detailed information about the installation status
    func installationStatus() -> InstallationStatus {
        let fileManager = FileManager.default
        
        // Check if Chrome directory exists
        let chromeDir = Self.chromeNativeMessagingDir.deletingLastPathComponent()
        let chromeExists = fileManager.fileExists(atPath: chromeDir.path)
        
        // Check if manifest exists
        let manifestExists = fileManager.fileExists(atPath: Self.manifestDestination.path)
        
        // Check if host binary exists in bundle
        let hostBinaryPath = findHostBinaryPath()
        let hostBinaryExists = hostBinaryPath != nil && fileManager.fileExists(atPath: hostBinaryPath!)
        
        return InstallationStatus(
            isInstalled: isInstalled(),
            chromeDirectoryExists: chromeExists,
            manifestExists: manifestExists,
            hostBinaryExists: hostBinaryExists,
            hostBinaryPath: hostBinaryPath,
            manifestPath: Self.manifestDestination.path
        )
    }
    
    // MARK: - Installation
    
    /// Attempts to install the native messaging host manifest
    /// - Returns: Result indicating success or failure with details
    func install() async -> InstallationResult {
        logger.info("Starting native messaging host installation...")
        
        // Check if already installed
        if isInstalled() {
            logger.info("Native messaging host already installed, skipping")
            return .alreadyInstalled
        }
        
        // Find the host binary
        guard let hostBinaryPath = findHostBinaryPath() else {
            logger.error("Could not find TabTimeHost binary in app bundle")
            return .failure(.hostBinaryNotFound)
        }
        
        // Verify host binary exists and is executable
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: hostBinaryPath) else {
            logger.error("TabTimeHost binary not found at expected path: \(hostBinaryPath)")
            return .failure(.hostBinaryNotFound)
        }
        
        // Ensure Chrome's NativeMessagingHosts directory exists
        do {
            try fileManager.createDirectory(
                at: Self.chromeNativeMessagingDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.debug("Created/verified Chrome NativeMessagingHosts directory")
        } catch {
            logger.error("Failed to create Chrome directory: \(error.localizedDescription)")
            return .failure(.permissionDenied(underlying: error))
        }
        
        // Generate and write the manifest
        let manifest = generateManifest(hostPath: hostBinaryPath)
        
        do {
            let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            try manifestData.write(to: Self.manifestDestination, options: .atomic)
            logger.info("Successfully installed native messaging host manifest at \(Self.manifestDestination.path)")
        } catch {
            logger.error("Failed to write manifest: \(error.localizedDescription)")
            return .failure(.writeFailed(underlying: error))
        }
        
        // Verify installation
        guard isInstalled() else {
            logger.error("Installation verification failed")
            return .failure(.verificationFailed)
        }
        
        logger.info("Native messaging host installation completed successfully")
        return .success
    }
    
    /// Force reinstall the native messaging host (even if already installed)
    func reinstall() async -> InstallationResult {
        logger.info("Force reinstalling native messaging host...")
        
        // Remove existing manifest if present
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: Self.manifestDestination.path) {
            do {
                try fileManager.removeItem(at: Self.manifestDestination)
                logger.debug("Removed existing manifest")
            } catch {
                logger.warning("Failed to remove existing manifest: \(error.localizedDescription)")
                // Continue anyway, we'll overwrite it
            }
        }
        
        return await install()
    }
    
    // MARK: - Private Helpers
    
    /// Finds the path to the TabTimeHost binary
    /// Searches in multiple locations: app bundle, build directories
    private func findHostBinaryPath() -> String? {
        let fileManager = FileManager.default
        
        // 1. Check app bundle (production path)
        if let bundlePath = Bundle.main.path(forResource: Self.hostBinaryName, ofType: nil) {
            return bundlePath
        }
        
        // 2. Check if we're running from Xcode/build directory
        let possiblePaths = [
            // Build directories (debug and release)
            "\(Bundle.main.bundlePath)/../.build/debug/\(Self.hostBinaryName)",
            "\(Bundle.main.bundlePath)/../.build/release/\(Self.hostBinaryName)",
            // Relative to executable
            "\(Bundle.main.bundlePath)/../../.build/debug/\(Self.hostBinaryName)",
            "\(Bundle.main.bundlePath)/../../.build/release/\(Self.hostBinaryName)",
            // Standard installation path
            "/Applications/TabPilot.app/Contents/MacOS/\(Self.hostBinaryName)"
        ]
        
        for path in possiblePaths {
            let resolvedPath = (path as NSString).standardizingPath
            if fileManager.fileExists(atPath: resolvedPath) {
                return resolvedPath
            }
        }
        
        return nil
    }
    
    /// Generates the manifest dictionary
    private func generateManifest(hostPath: String) -> [String: Any] {
        let configuredExtensionId = UserDefaults.standard.string(forKey: DefaultsKeys.extensionId)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowedOrigin: String
        if let configuredExtensionId, !configuredExtensionId.isEmpty {
            allowedOrigin = "chrome-extension://\(configuredExtensionId)/"
        } else {
            allowedOrigin = Self.defaultExtensionOrigin
        }

        return [
            "name": Self.hostName,
            "description": "TabPilot Tab Time Tracker Native Messaging Host",
            "path": hostPath,
            "type": "stdio",
            "allowed_origins": [allowedOrigin]
        ]
    }
}

// MARK: - Types

extension NativeMessagingHostInstaller {
    
    /// Result of an installation attempt
    enum InstallationResult {
        case success
        case alreadyInstalled
        case failure(InstallationError)
        
        var isSuccess: Bool {
            switch self {
            case .success, .alreadyInstalled:
                return true
            case .failure:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .success:
                return "Native messaging host installed successfully"
            case .alreadyInstalled:
                return "Native messaging host is already installed"
            case .failure(let error):
                return "Installation failed: \(error.localizedDescription)"
            }
        }
    }
    
    /// Detailed errors that can occur during installation
    enum InstallationError: Error, LocalizedError {
        case hostBinaryNotFound
        case permissionDenied(underlying: Error)
        case writeFailed(underlying: Error)
        case verificationFailed
        
        var errorDescription: String? {
            switch self {
            case .hostBinaryNotFound:
                return "TabTimeHost binary not found in app bundle"
            case .permissionDenied(let underlying):
                return "Permission denied: \(underlying.localizedDescription)"
            case .writeFailed(let underlying):
                return "Failed to write manifest: \(underlying.localizedDescription)"
            case .verificationFailed:
                return "Installation verification failed"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .hostBinaryNotFound:
                return "Please ensure the app is properly installed."
            case .permissionDenied:
                return "Check that you have write permissions to ~/Library/Application Support/Google/Chrome/"
            case .writeFailed:
                return "Try restarting the app or checking disk space."
            case .verificationFailed:
                return "The manifest was written but couldn't be verified. Try reinstalling."
            }
        }
    }
    
    /// Detailed status of the installation
    struct InstallationStatus {
        let isInstalled: Bool
        let chromeDirectoryExists: Bool
        let manifestExists: Bool
        let hostBinaryExists: Bool
        let hostBinaryPath: String?
        let manifestPath: String
        
        var isReadyForInstallation: Bool {
            hostBinaryExists && chromeDirectoryExists
        }
        
        var summary: String {
            var parts: [String] = []
            parts.append("Installed: \(isInstalled ? "Yes" : "No")")
            parts.append("Chrome Directory: \(chromeDirectoryExists ? "Exists" : "Missing")")
            parts.append("Manifest: \(manifestExists ? "Exists" : "Missing")")
            parts.append("Host Binary: \(hostBinaryExists ? "Found" : "Not Found")")
            if let path = hostBinaryPath {
                parts.append("Binary Path: \(path)")
            }
            return parts.joined(separator: "\n")
        }
    }
}
