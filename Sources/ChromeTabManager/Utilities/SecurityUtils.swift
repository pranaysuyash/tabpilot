import Foundation
import CryptoKit

/// Security utilities for the app.
/// Provides URL validation, input sanitization, and secure logging.
enum SecurityUtils {
    
    // MARK: - URL Validation
    
    /// Validate and clean a URL string. Returns nil for unsafe schemes.
    static func sanitizeURL(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), isAllowedScheme(url) else { return nil }
        return trimmed
    }
    
    /// Strip control characters and limit title to 500 chars.
    static func sanitizeTitle(_ title: String) -> String {
        let stripped = title.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        return String(String.UnicodeScalarView(stripped).prefix(500))
    }
    
    /// Only allow http, https, chrome schemes.
    static func isAllowedScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "chrome"].contains(scheme)
    }
    
    /// Check for AppleScript injection patterns.
    static func validateAppleScriptOutput(_ string: String) -> Bool {
        let dangerous = ["do shell script", "tell application", "osascript", "<script", "javascript:"]
        let lower = string.lowercased()
        return !dangerous.contains { lower.contains($0) }
    }
    
    /// Validate that a URL string is safe to open in Chrome.
    /// Rejects file://, javascript:, and data: URLs.
    static func isSafeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let scheme = url.scheme?.lowercased() ?? ""
        return scheme == "http" || scheme == "https"
    }
    
    /// Sanitize a URL string for safe display (remove credentials from URL)
    static func sanitizeURLForDisplay(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.user = nil
        components.password = nil
        return components.string ?? urlString
    }
    
    // MARK: - Input Sanitization
    
    /// Sanitize a domain string — strip scheme, trailing slashes, whitespace.
    static func sanitizeDomain(_ input: String) -> String {
        var domain = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Strip scheme
        for prefix in ["https://", "http://", "//"]{
            if domain.hasPrefix(prefix) {
                domain = String(domain.dropFirst(prefix.count))
            }
        }
        
        // Strip path
        if let slashIndex = domain.firstIndex(of: "/") {
            domain = String(domain[..<slashIndex])
        }
        
        // Strip trailing dots
        while domain.hasSuffix(".") {
            domain = String(domain.dropLast())
        }
        
        return domain
    }
    
    /// Validate that a domain string looks like a real domain.
    static func isValidDomain(_ domain: String) -> Bool {
        let sanitized = sanitizeDomain(domain)
        guard !sanitized.isEmpty else { return false }
        
        if sanitized == "localhost" { return true }
        
        let parts = sanitized.components(separatedBy: ".")
        return parts.count >= 2 && parts.allSatisfy { !$0.isEmpty }
    }
    
    // MARK: - Data Validation
    
    /// Validate session name is safe to save to disk.
    static func sanitizeSessionName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "/", with: "-")
                      .replacingOccurrences(of: "\\", with: "-")
                      .replacingOccurrences(of: ":", with: "-")
                      .replacingOccurrences(of: "*", with: "")
                      .replacingOccurrences(of: "?", with: "")
                      .replacingOccurrences(of: "\"", with: "")
                      .replacingOccurrences(of: "<", with: "")
                      .replacingOccurrences(of: ">", with: "")
                      .replacingOccurrences(of: "|", with: "-")
    }
}
