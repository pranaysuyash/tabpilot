import Foundation

struct URLPattern: Codable, Identifiable, Equatable {
    let id: UUID
    var pattern: String
    var enabled: Bool
    var description: String

    init(id: UUID = UUID(), pattern: String, enabled: Bool = true, description: String = "") {
        self.id = id
        self.pattern = pattern
        self.enabled = enabled
        self.description = description
    }

    func matches(_ url: String) -> Bool {
        guard enabled else { return false }

        var regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        regexPattern = regexPattern.replacingOccurrences(of: "\\*", with: ".*")

        let fullPattern: String
        if pattern.hasPrefix("http") || pattern.hasPrefix("*") {
            fullPattern = "^\(regexPattern)$"
        } else {
            fullPattern = "\(regexPattern)$"
        }

        guard let regex = try? NSRegularExpression(pattern: fullPattern, options: .caseInsensitive) else {
            return url.lowercased().contains(pattern.replacingOccurrences(of: "*", with: "").lowercased())
        }

        let range = NSRange(url.startIndex..., in: url)
        return regex.firstMatch(in: url, options: [], range: range) != nil
    }
}

@MainActor
final class URLPatternStore: @unchecked Sendable {
    static let shared = URLPatternStore()

    private let patternsKey = "urlPatterns"
    private let userDefaults = UserDefaults.standard
    private let lock = NSLock()

    private init() {}

    func loadPatterns() -> [URLPattern] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: patternsKey) else {
            return defaultPatterns()
        }

        do {
            let patterns = try JSONDecoder().decode([URLPattern].self, from: data)
            return patterns.isEmpty ? defaultPatterns() : patterns
        } catch {
            print("URLPatternStore: Failed to decode patterns: \(error.localizedDescription)")
            return defaultPatterns()
        }
    }

    func savePatterns(_ patterns: [URLPattern]) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let data = try JSONEncoder().encode(patterns)
            userDefaults.set(data, forKey: patternsKey)
        } catch {
            print("URLPatternStore: Failed to encode patterns: \(error.localizedDescription)")
        }
    }

    private func defaultPatterns() -> [URLPattern] {
        [
            URLPattern(pattern: "*.google.com", description: "Google services"),
            URLPattern(pattern: "*.github.com", description: "GitHub"),
            URLPattern(pattern: "*.stackoverflow.com", description: "Stack Overflow")
        ]
    }
}
