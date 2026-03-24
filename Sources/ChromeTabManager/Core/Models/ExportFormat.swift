import Foundation

enum ExportFormat: String, CaseIterable, Sendable {
    case json = "JSON"
    case html = "HTML"
    case markdown = "Markdown"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .html: return "html"
        case .markdown: return "md"
        }
    }
}
