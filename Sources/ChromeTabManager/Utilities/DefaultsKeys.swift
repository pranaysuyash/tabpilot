import Foundation

/// Centralized constants for UserDefaults keys.
/// Use these instead of string literals scattered throughout the codebase.
enum DefaultsKeys {
    // MARK: - License
    static let isProPurchased = "isProPurchased"
    
    // MARK: - Tab Timestamps
    static let tabTimestamps = "tabTimestamps"
    
    // MARK: - Protected Domains
    static let protectedDomains = "protectedDomains"
    
    // MARK: - Preferences
    static let defaultKeepPolicy = "defaultKeepPolicy"
    static let confirmDestructive = "confirmDestructive"
    static let ignoreTrackingParams = "ignoreTrackingParams"
    static let stripQueryParams = "stripQueryParams"
    static let maxDuplicatesDisplay = "maxDuplicatesDisplay"
    static let defaultExportFormat = "defaultExportFormat"
    static let archiveLocationPath = "archiveLocationPath"
    static let recentArchivePaths = "recentArchivePaths"
    
    // MARK: - Statistics Store
    static let usageStatistics = "usageStatistics"
    
    // MARK: - Closed Tab History Store
    static let closedTabHistory = "closedTabHistory"
    
    // MARK: - Cleanup Rules Store
    static let cleanupRules = "cleanupRules"
    
    // MARK: - Sessions Store
    static let savedSessions = "savedSessions"
    
    // MARK: - Auto-Cleanup
    static let autoCleanupEnabled = "autoCleanupEnabled"
    static let autoCleanupMaxAge = "autoCleanupMaxAge"
    static let autoCleanupInterval = "autoCleanupInterval"
    
    // MARK: - UI State
    static let lastSelectedViewMode = "lastSelectedViewMode"
    static let onboardingComplete = "onboardingComplete"
    
    // MARK: - Notification Settings
    static let notificationsEnabled = "notificationsEnabled"
    static let notificationGlobalThreshold = "notificationGlobalThreshold"
    static let notificationCooldown = "notificationCooldown"
    static let notificationQuietHoursEnabled = "notificationQuietHoursEnabled"
    static let notificationQuietHoursStart = "notificationQuietHoursStart"
    static let notificationQuietHoursEnd = "notificationQuietHoursEnd"
    static let notificationWeeklySummary = "notificationWeeklySummary"
    static let notificationDomainThresholds = "notificationDomainThresholds"
    static let notificationIgnoredDomains = "notificationIgnoredDomains"
    
    // MARK: - Extension Installation
    static let extensionDataReceived = "extensionDataReceived"
    static let extensionInstallationDontShowAgain = "extensionInstallationDontShowAgain"
    static let extensionInstallationLastPromptDate = "extensionInstallationLastPromptDate"
}
