import Foundation
import SwiftUI

enum DegradationLevel: String, Codable, Sendable {
    case full
    case partial
    case minimal
    case offline
}

@MainActor
final class GracefulDegradationManager: ObservableObject {
    static let shared = GracefulDegradationManager()
    
    @Published private(set) var currentLevel: DegradationLevel = .full
    @Published private(set) var lastDegradationReason: String?
    
    private init() {}
    
    func adaptToError(_ error: any Error) {
        if let chromeError = error as? ChromeError {
            switch chromeError {
            case .notRunning:
                degradeTo(.partial, reason: "Chrome is not running")
            case .timeout:
                degradeTo(.partial, reason: "Chrome is not responding")
            case .appleScriptFailed:
                degradeTo(.minimal, reason: "AppleScript permission issue")
            case .ambiguousMatch:
                degradeTo(.partial, reason: "Tab matching ambiguous")
            }
        } else if let userError = error as? UserFacingError {
            switch userError {
            case .networkError:
                degradeTo(.offline, reason: "Network unavailable")
            case .archiveFailed:
                degradeTo(.partial, reason: "Archive storage unavailable")
            case .licenseVerificationFailed:
                degradeTo(.minimal, reason: "License verification failed")
            default:
                break
            }
        }
    }
    
    func adaptToChromeNotRunning() {
        degradeTo(.partial, reason: "Chrome is not running")
    }
    
    func adaptToNoNetwork() {
        degradeTo(.offline, reason: "Network connection unavailable")
    }
    
    func adaptToStorageFull() {
        degradeTo(.minimal, reason: "Storage full")
    }
    
    func recover() {
        guard currentLevel != .full else { return }
        currentLevel = .full
        lastDegradationReason = nil
        SecureLogger.info("GracefulDegradationManager: recovered to full functionality")
    }
    
    private func degradeTo(_ level: DegradationLevel, reason: String) {
        guard level != currentLevel else { return }
        
        let oldLevel = currentLevel
        currentLevel = level
        lastDegradationReason = reason
        
        SecureLogger.warning("GracefulDegradationManager: degraded from \(oldLevel) to \(level): \(reason)")
        
        notifyUser(of: level, reason: reason)
    }
    
    private func notifyUser(of level: DegradationLevel, reason: String) {
        let message: String
        switch level {
        case .full:
            return
        case .partial:
            message = "Some features temporarily unavailable: \(reason)"
        case .minimal:
            message = "Read-only mode: \(reason)"
        case .offline:
            message = "Working offline - changes will sync when connection restored"
        }
        
        NotificationCenter.default.post(
            name: Notification.Name("showToast"),
            object: nil,
            userInfo: ["message": message, "type": "warning"]
        )
    }
}

@MainActor
enum FeatureFlags {
    static var canCloseTabs: Bool {
        GracefulDegradationManager.shared.currentLevel == .full
    }
    
    static var canArchive: Bool {
        GracefulDegradationManager.shared.currentLevel == .full
    }
    
    static var canExport: Bool {
        GracefulDegradationManager.shared.currentLevel != .offline
    }
    
    static var canScan: Bool {
        GracefulDegradationManager.shared.currentLevel == .full
    }
    
    static var canOpenTabs: Bool {
        GracefulDegradationManager.shared.currentLevel == .full
    }
    
    static var canModifyPreferences: Bool {
        GracefulDegradationManager.shared.currentLevel == .full
    }
    
    static var isReadOnly: Bool {
        GracefulDegradationManager.shared.currentLevel == .minimal
    }
}
