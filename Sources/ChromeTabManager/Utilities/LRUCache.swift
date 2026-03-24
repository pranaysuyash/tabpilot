import Foundation

/// A simple LRU (Least Recently Used) cache with a maximum size limit
/// Automatically evicts oldest entries when capacity is reached
final class LRUCache<Key: Hashable, Value> {
    private let maxSize: Int
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let lock = NSLock()
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let value = cache[key] else { return nil }
        
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
        
        return value
    }
    
    func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        
        if cache[key] != nil {
            cache[key] = value
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
                accessOrder.append(key)
            }
            return
        }
        
        if cache.count >= maxSize && !accessOrder.isEmpty {
            let oldestKey = accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
        
        cache[key] = value
        accessOrder.append(key)
    }
    
    func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeValue(forKey: key)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
    
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache.isEmpty
    }
}

/// Thread-safe cache key for filtered duplicates
struct FilterCacheKey: Hashable {
    let searchQuery: String
    let viewMode: String
}