import Foundation
import AppKit

/// Manages detection and presentation of the Chrome extension installation guide
@MainActor
final class ExtensionInstallationManager: ObservableObject {
    static let shared = ExtensionInstallationManager()
    
    @Published var showInstallationGuide = false
    @Published var extensionDataAvailable = false
    
    private let userDefaults: UserDefaults
    private let tabTimeStore: TabTimeStore
    
    private init(userDefaults: UserDefaults = .standard, tabTimeStore: TabTimeStore = .shared) {
        self.userDefaults = userDefaults
        self.tabTimeStore = tabTimeStore
    }
    
    /// Checks if the Chrome extension is providing data
    func checkExtensionAvailability() async {
        let isAvailable = await tabTimeStore.isAvailable()
        extensionDataAvailable = isAvailable
        
        if isAvailable {
            userDefaults.set(true, forKey: DefaultsKeys.extensionDataReceived)
        }
    }
    
    /// Determines if the installation guide should be shown
    func shouldShowGuide() -> Bool {
        // Don't show if user said "Don't show again"
        if userDefaults.bool(forKey: DefaultsKeys.extensionInstallationDontShowAgain) {
            return false
        }
        
        // Don't show if extension data is already available
        if extensionDataAvailable {
            return false
        }
        
        // Check if we've shown the prompt recently (within last 7 days)
        if let lastPromptDate = userDefaults.object(forKey: DefaultsKeys.extensionInstallationLastPromptDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
            if daysSinceLastPrompt < 7 {
                return false
            }
        }
        
        return true
    }
    
    /// Records that the guide was shown
    func recordGuideShown() {
        userDefaults.set(Date(), forKey: DefaultsKeys.extensionInstallationLastPromptDate)
    }
    
    /// Marks that the user doesn't want to see the guide again
    func markDontShowAgain() {
        userDefaults.set(true, forKey: DefaultsKeys.extensionInstallationDontShowAgain)
    }
    
    /// Opens Chrome to the extensions page
    func openChromeExtensions() {
        let chromeURL = URL(string: "chrome://extensions")!
        NSWorkspace.shared.open(chromeURL)
    }
    
    /// Shows the installation guide immediately
    func showGuide() {
        showInstallationGuide = true
        recordGuideShown()
    }
    
    /// Dismisses the guide and records it was shown
    func dismissGuide() {
        showInstallationGuide = false
        recordGuideShown()
    }
    
    /// Resets all preferences (useful for testing)
    func resetPreferences() {
        userDefaults.removeObject(forKey: DefaultsKeys.extensionInstallationDontShowAgain)
        userDefaults.removeObject(forKey: DefaultsKeys.extensionInstallationLastPromptDate)
        userDefaults.removeObject(forKey: DefaultsKeys.extensionDataReceived)
    }
}
