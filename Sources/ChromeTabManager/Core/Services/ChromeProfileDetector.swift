import Foundation
@preconcurrency import ApplicationServices
import AppKit

/// Detects Chrome profiles and maps windows to profile names.
///
/// Chrome supports multiple profiles (Default, Profile 1, Profile 2, etc.).
/// Each profile has its own windows. AppleScript's `tell application "Google Chrome"`
/// sees ALL windows across all profiles but doesn't tell us which profile owns which window.
///
/// Detection strategy:
/// 1. Read `~/Library/Application Support/Google/Chrome/Local State` JSON to enumerate profiles
/// 2. Use Accessibility API to read Chrome window titles (which include profile names)
/// 3. Match window titles to profiles and return a per-window mapping
struct ChromeProfileDetector: Sendable {

    struct ChromeProfile: Sendable, Identifiable {
        let id: String
        let displayName: String
    }

    /// Mapping result: 1-based window index (matches AppleScript ordering) → profile name
    struct ProfileMapping: Sendable {
        let windowProfiles: [Int: String]
        let allProfiles: [ChromeProfile]

        func profileName(forWindow windowIndex: Int) -> String {
            windowProfiles[windowIndex] ?? "Default"
        }
    }

    // MARK: - Public API

    static func detectProfiles() async -> ProfileMapping {
        let profiles = readProfileList()
        let axMapping = mapWindowsViaAccessibility(profiles: profiles)

        return ProfileMapping(
            windowProfiles: axMapping,
            allProfiles: profiles
        )
    }

    // MARK: - Local State Parsing

    private static func readProfileList() -> [ChromeProfile] {
        guard let chromeSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return [] }

        let localStateURL = chromeSupportURL
            .appendingPathComponent("Google")
            .appendingPathComponent("Chrome")
            .appendingPathComponent("Local State")

        guard FileManager.default.fileExists(atPath: localStateURL.path),
              let data = try? Data(contentsOf: localStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            return []
        }

        var profiles: [ChromeProfile] = []
        for (profileId, profileData) in infoCache {
            guard let profileDict = profileData as? [String: Any] else { continue }
            let name = profileDict["name"] as? String ?? profileId
            profiles.append(ChromeProfile(id: profileId, displayName: name))
        }

        return profiles.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Accessibility API Window Mapping

    private static func mapWindowsViaAccessibility(profiles: [ChromeProfile]) -> [Int: String] {
        guard AXIsProcessTrusted() else { return [:] }

        let chromeApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.google.Chrome"
        }
        guard let chromeApp = chromeApps.first else { return [:] }

        let pid = chromeApp.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var windowListRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            appRef,
            kAXWindowsAttribute as CFString,
            &windowListRef
        )
        guard windowResult == .success,
              let windows = windowListRef as? [AXUIElement] else {
            return [:]
        }

        let knownProfileNames = Set(profiles.map { $0.displayName.lowercased() })
        let knownProfileIds = Set(profiles.map { $0.id.lowercased() })

        var mapping: [Int: String] = [:]
        for (index, window) in windows.enumerated() {
            let windowIndex = index + 1

            guard let title = readAXWindowTitle(window) else { continue }

            let profileName = extractProfileName(
                from: title,
                knownNames: knownProfileNames,
                knownIds: knownProfileIds,
                profiles: profiles
            )
            mapping[windowIndex] = profileName
        }

        return mapping
    }

    private static func readAXWindowTitle(_ window: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleRef
        )
        guard result == .success, let title = titleRef as? String else {
            return nil
        }
        return title
    }

    private static func extractProfileName(
        from title: String,
        knownNames: Set<String>,
        knownIds: Set<String>,
        profiles: [ChromeProfile]
    ) -> String {
        let separators = [" - Google Chrome (", " — Google Chrome ("]
        for sep in separators {
            guard let sepRange = title.range(of: sep) else { continue }
            let afterSep = title[sepRange.upperBound...]
            guard let closeParen = afterSep.lastIndex(of: ")") else { continue }
            let extracted = String(afterSep[afterSep.startIndex..<closeParen])
                .trimmingCharacters(in: .whitespaces)

            let extractedLower = extracted.lowercased()
            if knownNames.contains(extractedLower) {
                return extracted
            }

            if knownIds.contains(extractedLower) {
                if let profile = profiles.first(where: { $0.id.lowercased() == extractedLower }) {
                    return profile.displayName
                }
                return extracted
            }

            if !extracted.isEmpty {
                return extracted
            }
        }

        return "Default"
    }
}
