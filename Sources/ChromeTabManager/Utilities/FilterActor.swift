import Foundation

/// Actor for performing expensive filtering operations off the main thread
actor FilterActor {
    static let shared = FilterActor()
    
    private init() {}
    
    /// Filter duplicate groups based on search terms
    /// - Parameters:
    ///   - groups: The groups to filter
    ///   - searchQuery: The search string (already debounced)
    ///   - maxResults: Maximum number of results to return
    /// - Returns: Filtered array of duplicate groups
    func filterDuplicates(
        groups: [DuplicateGroup],
        searchQuery: String,
        maxResults: Int
    ) -> [DuplicateGroup] {
        guard !searchQuery.isEmpty else {
            return Array(groups.prefix(maxResults))
        }
        
        let searchTerms = searchQuery.lowercased()
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        
        guard !searchTerms.isEmpty else {
            return Array(groups.prefix(maxResults))
        }
        
        var results: [DuplicateGroup] = []
        results.reserveCapacity(min(maxResults, groups.count))
        
        for group in groups {
            if results.count >= maxResults {
                break
            }
            
            var matchesAll = true
            
            searchLoop: for term in searchTerms {
                var foundInGroup = false
                
                for tab in group.tabs {
                    if tab.title.lowercased().contains(term) ||
                       tab.url.lowercased().contains(term) ||
                       tab.domain.lowercased().contains(term) {
                        foundInGroup = true
                        break
                    }
                }
                
                if !foundInGroup {
                    matchesAll = false
                    break searchLoop
                }
            }
            
            if matchesAll {
                results.append(group)
            }
        }
        
        return results
    }
    
    /// Pre-compute searchable text for tabs to speed up future filtering
    /// This creates a flattened index of all searchable content
    func buildSearchIndex(for groups: [DuplicateGroup]) -> [String: Set<String>] {
        var index: [String: Set<String>] = [:]
        
        for group in groups {
            var terms: Set<String> = []
            
            for tab in group.tabs {
                let titleWords = tab.title.lowercased()
                    .components(separatedBy: .alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                terms.formUnion(titleWords)
                
                let domainParts = tab.domain.lowercased()
                    .components(separatedBy: ".")
                    .filter { !$0.isEmpty }
                terms.formUnion(domainParts)
                
                if let url = URL(string: tab.url),
                   let pathComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path {
                    let pathWords = pathComponents.lowercased()
                        .components(separatedBy: "/")
                        .filter { !$0.isEmpty }
                    terms.formUnion(pathWords)
                }
            }
            
            index[group.id] = terms
        }
        
        return index
    }
}