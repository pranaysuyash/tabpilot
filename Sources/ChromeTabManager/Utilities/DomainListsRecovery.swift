import Foundation

// RECOVERY ADDON: curated baseline domain sets for safer automation defaults.
enum DomainListsRecovery {
    static let neverCloseDomains: Set<String> = [
        "mail.google.com",
        "calendar.google.com",
        "docs.google.com",
        "meet.google.com",
        "teams.microsoft.com",
        "notion.so",
        "figma.com",
        "github.com"
    ]

    static let noisyTrackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "gclid", "fbclid", "mc_cid", "mc_eid", "igshid", "ref", "source"
    ]
}
