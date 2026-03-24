import SwiftUI

@MainActor
@Observable
final class TabSelectionController {
    // MARK: - Selection State
    var selectedTabIds: Set<String> = []
    
    // MARK: - Search & Filter State
    var searchQuery: String = "" {
        didSet { scheduleSearchDebounce() }
    }
    private(set) var debouncedSearchQuery: String = ""
    private(set) var filteredDuplicates: [DuplicateGroup] = []
    
    // MARK: - View Mode
    var viewMode: DuplicateViewMode = .overall {
        didSet { updateFilteredDuplicates() }
    }
    
    // MARK: - Dependencies
    private let filteredResultsCache = LRUCache<FilterCacheKey, [DuplicateGroup]>(maxSize: 50)
    private var filterTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    
    // MARK: - Closure-based Provider (for cross-controller access)
    private var _duplicateGroupsProvider: (() -> [DuplicateGroup])?
    
    var duplicateGroupsProvider: (() -> [DuplicateGroup])? {
        get { _duplicateGroupsProvider }
        set {
            _duplicateGroupsProvider = newValue
            updateFilteredDuplicates()
        }
    }
    
    // MARK: - Initialization
    init() {
        updateFilteredDuplicates()
    }
    
    convenience init(duplicateGroupsProvider: @escaping () -> [DuplicateGroup]) {
        self.init()
        self.duplicateGroupsProvider = duplicateGroupsProvider
    }
    
    func setDuplicateGroupsProvider(_ provider: @escaping () -> [DuplicateGroup]) {
        self.duplicateGroupsProvider = provider
    }
    
    // MARK: - Debounced Search
    private func scheduleSearchDebounce() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self = self, !Task.isCancelled else { return }
            guard self.searchQuery != self.debouncedSearchQuery else { return }
            self.debouncedSearchQuery = self.searchQuery
            self.invalidateDuplicateCache()
        }
    }
    
    // MARK: - Duplicate Access
    var duplicateGroups: [DuplicateGroup] {
        duplicateGroupsProvider?() ?? []
    }
    
    var duplicatesForCurrentMode: [DuplicateGroup] {
        switch viewMode {
        case .overall:
            return duplicateGroups
        case .byWindow:
            return duplicateGroupsByWindow
        case .byDomain:
            return duplicateGroupsByDomain
        case .crossWindow:
            return crossWindowDuplicates
        }
    }
    
    var duplicateGroupsByWindow: [DuplicateGroup] {
        var groupsByWindow: [Int: [DuplicateGroup]] = [:]

        for group in duplicateGroups {
            let windowIds = Set(group.tabs.map { $0.windowId })
            for windowId in windowIds {
                groupsByWindow[windowId, default: []].append(group)
            }
        }

        return groupsByWindow.keys.sorted().flatMap { groupsByWindow[$0] ?? [] }
    }
    
    var duplicateGroupsByDomain: [DuplicateGroup] {
        let domainGroups = Dictionary(grouping: duplicateGroups) { group in
            group.tabs.first?.domain ?? "unknown"
        }
        
        return domainGroups.sorted { $0.value.count > $1.value.count }.flatMap { $0.value }
    }
    
    var crossWindowDuplicates: [DuplicateGroup] {
        duplicateGroups.filter { group in
            let uniqueWindows = Set(group.tabs.map { $0.windowId })
            return uniqueWindows.count > 1
        }
    }
    
    var hasDuplicates: Bool {
        !duplicateGroups.isEmpty
    }
    
    // MARK: - Filtered Results
    func updateFilteredDuplicates() {
        filterTask?.cancel()
        
        let groups = duplicatesForCurrentMode
        let searchQuery = debouncedSearchQuery
        let viewModeStr = viewMode.rawValue
        let maxResults = 100 // TODO: get from config
        let cacheKey = FilterCacheKey(searchQuery: searchQuery, viewMode: viewModeStr)
        
        if let cached = filteredResultsCache.get(cacheKey) {
            filteredDuplicates = cached
            return
        }
        
        if searchQuery.isEmpty {
            let result = Array(groups.prefix(maxResults))
            filteredResultsCache.set(cacheKey, value: result)
            filteredDuplicates = result
            return
        }
        
        filterTask = Task {
            let result = await FilterActor.shared.filterDuplicates(
                groups: groups,
                searchQuery: searchQuery,
                maxResults: maxResults
            )
            
            guard !Task.isCancelled else { return }
            
            filteredResultsCache.set(cacheKey, value: result)
            filteredDuplicates = result
        }
    }
    
    func invalidateDuplicateCache() {
        filteredResultsCache.removeAll()
        updateFilteredDuplicates()
    }
    
    // MARK: - Selection Methods
    func selectAll() {
        selectedTabIds = Set(duplicateGroups.flatMap { $0.tabs.map { $0.id } })
    }
    
    func selectDuplicates() {
        selectedTabIds.removeAll()
        for group in duplicateGroups {
            let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
            for tab in sorted.dropFirst() {
                selectedTabIds.insert(tab.id)
            }
        }
    }
    
    func deselectAll() {
        selectedTabIds.removeAll()
    }
    
    func toggleSelection(for tabId: String) {
        if selectedTabIds.contains(tabId) {
            selectedTabIds.remove(tabId)
        } else {
            selectedTabIds.insert(tabId)
        }
    }
    
    func selectAll(in group: DuplicateGroup) {
        for tab in group.tabs {
            selectedTabIds.insert(tab.id)
        }
    }
    
    func selectAllExceptOldest(in group: DuplicateGroup) {
        let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
        for tab in sorted.dropFirst() {
            selectedTabIds.insert(tab.id)
        }
    }
    
    func selectAllExceptNewest(in group: DuplicateGroup) {
        let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
        for tab in sorted.dropLast() {
            selectedTabIds.insert(tab.id)
        }
    }
    
    func smartSelect() {
        selectedTabIds.removeAll()
        for group in duplicateGroups {
            let sorted = group.tabs.sorted { $0.openedAt < $1.openedAt }
            for tab in sorted.dropFirst() {
                selectedTabIds.insert(tab.id)
            }
        }
    }
}
