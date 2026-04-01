/**
 * VERİ ENTEGRASYONU - PERFORMANS VE CACHE (COMPLETED)
 * Bu manager, API'den çekilen verilerin (Kripto/BIST) RAM üzerinde
 * geçici olarak tutulmasını sağlar. Böylece sekmeler arası geçişte
 * uygulama çok daha hızlı ve akıcı bir deneyim sunar.
 */
```



import Foundation

/// In-memory cache for temporary API data (MarketData, News, etc.).
/// Uses `NSCache` to automatically purge entries under memory pressure.
final class CacheManager {
    static let shared = CacheManager()

    private let cache = NSCache<NSString, CacheBox>()
    private let lock = NSLock()

    private init() {
        cache.name = "com.borsaApp.CacheManager"
    }

    /// Stores a value in memory cache.
    /// - Parameters:
    ///   - key: Cache key.
    ///   - value: Any value to cache (e.g. `MarketData`, `[News]`, etc.).
    func setCache<T>(key: String, value: T) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(CacheBox(value), forKey: key as NSString)
    }

    /// Fetches a cached value for the given key.
    /// - Parameter key: Cache key.
    /// - Returns: The cached value casted to the expected type, or `nil`.
    func getCache<T>(key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: key as NSString)?.value as? T
    }

    /// Clears all cached values.
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
}

private final class CacheBox: NSObject {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }
}
