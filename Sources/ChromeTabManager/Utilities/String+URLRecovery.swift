import Foundation

// RECOVERY ADDON: deterministic URL normalization helper for duplicate matching.
enum URLNormalizerRecovery {
    static func normalize(_ raw: String, stripWWW: Bool = true, dropFragment: Bool = true) -> String {
        guard var comps = URLComponents(string: raw),
              let host = comps.host?.lowercased() else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        comps.scheme = comps.scheme?.lowercased()
        comps.host = stripWWW ? host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression) : host

        if dropFragment {
            comps.fragment = nil
        }

        if var items = comps.queryItems, !items.isEmpty {
            items.removeAll { DomainListsRecovery.noisyTrackingParams.contains($0.name.lowercased()) }
            comps.queryItems = items.isEmpty ? nil : items.sorted { $0.name < $1.name }
        }

        return comps.url?.absoluteString ?? raw
    }
}
