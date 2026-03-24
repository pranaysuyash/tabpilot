import Foundation

enum AppVersion {
    static let major = 1
    static let minor = 0
    static let patch = 0
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static var full: String {
        "\(major).\(minor).\(patch) (\(build))"
    }

    static var short: String {
        "\(major).\(minor).\(patch)"
    }
}
