import Foundation

struct TrackedSourceInfo {
    let name: String
    let parameter: String
}

public func extractTrackingSources(from urlString: String) -> [String] {
    guard let url = URL(string: urlString),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems else {
        return []
    }
    
    var sources: [String] = []
    
    for item in queryItems {
        guard let value = item.value, !value.isEmpty else { continue }
        
        switch item.name.lowercased() {
        case "fbclid", "fb_action_ids", "fb_action_types", "fb_source":
            sources.append("Facebook")
        case "gclid", "gclsrc":
            sources.append("Google Ads")
        case "utm_source":
            sources.append("Google Analytics (UTM)")
        case "utm_medium":
            sources.append("Google Analytics (UTM Medium)")
        case "utm_campaign":
            sources.append("Google Analytics (UTM Campaign)")
        case "utm_term":
            sources.append("Google Analytics (UTM Term)")
        case "utm_content":
            sources.append("Google Analytics (UTM Content)")
        case "ttclid":
            sources.append("TikTok Ads")
        case "twclid":
            sources.append("Twitter Ads")
        case "mc_cid", "mc_eid":
            sources.append("Mailchimp")
        case "ref", "ref_", "reference":
            sources.append("Affiliate/Referral")
        case "affiliate", "aff_id", "affiliate_id":
            sources.append("Affiliate")
        case "partner", "partner_id":
            sources.append("Partner")
        case "cmp_id", "campaign_id":
            sources.append("Campaign")
        default:
            break
        }
    }
    
    return Array(Set(sources)).sorted()
}

public func extractPrimaryTrackingSource(from urlString: String) -> String? {
    let sources = extractTrackingSources(from: urlString)
    
    let priorityOrder = ["Google Ads", "Facebook", "TikTok Ads", "Twitter Ads", "Mailchimp", "Affiliate", "Affiliate/Referral", "Partner", "Campaign", "Google Analytics (UTM)", "Google Analytics (UTM Medium)", "Google Analytics (UTM Campaign)", "Google Analytics (UTM Term)", "Google Analytics (UTM Content)"]
    
    for priority in priorityOrder {
        if sources.contains(priority) {
            return priority
        }
    }
    
    return sources.first
}
