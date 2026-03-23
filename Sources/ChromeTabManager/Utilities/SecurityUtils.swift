import Foundation
import CryptoKit

/// Security utilities for the app.
/// Provides URL validation, input sanitization, and secure logging.
enum SecurityUtils {
    
    // MARK: - URL Validation
    
    /// Validate that a URL string is safe to open in Chrome.
    /// Rejects file://, javascript:, and data: URLs.
    static func isSafeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let scheme = url.scheme?.lowercased() ?? ""
        
        // Only allow http and https
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
        
        // Basic: must contain at least one dot (e.g., google.com)
        // or be a valid localhost
        if sanitized == "localhost" { return true }
        
        let parts = sanitized.components(separatedBy: ".")
        return parts.count >= 2 && parts.allSatisfy { !$0.isEmpty }
    }
    
    // MARK: - Data Validation
    
    /// Validate session name is safe to save to disk.
    static func sanitizeSessionName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace filesystem unsafe chars
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
