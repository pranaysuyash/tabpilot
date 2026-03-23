import Foundation

// RECOVERY ADDON: markdown-safe escaping for export/report generation.
extension String {
    func escapedForMarkdownRecovery() -> String {
        var result = self
        let replacements: [(String, String)] = [
            ("\\", "\\\\"), ("`", "\\`"), ("*", "\\*"), ("_", "\\_"),
            ("[", "\\["), ("]", "\\]"), ("(", "\\("), (")", "\\)"),
            ("#", "\\#"), ("+", "\\+"), ("-", "\\-"), ("!", "\\!")
        ]
        for (target, replacement) in replacements {
            result = result.replacingOccurrences(of: target, with: replacement)
        }
        return result
    }
}
