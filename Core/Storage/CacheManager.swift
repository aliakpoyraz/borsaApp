/**
 * VERİ ENTEGRASYONU - PERFORMANS VE CACHE (COMPLETED)
 * Bu manager, API'den çekilen verilerin (Kripto/BIST) RAM üzerinde
 * geçici olarak tutulmasını sağlar. Böylece sekmeler arası geçişte
 * uygulama çok daha hızlı ve akıcı bir deneyim sunar.
 */
import Foundation

/// Geçici API verileri (Piyasa Verileri, Haberler vb.) için bellek içi (in-memory) önbellek.
/// Bellek baskısı altında girişleri otomatik olarak temizlemek için `NSCache` kullanır.
final class CacheManager {
    static let shared = CacheManager()

    private let cache = NSCache<NSString, CacheBox>()
    private let lock = NSLock()

    private init() {
        cache.name = "com.borsaApp.CacheManager"
    }

    /// Önbelleğe (cache) bir değer kaydeder.
    /// - Parametreler:
    ///   - key: Önbellek anahtarı.
    ///   - value: Önbelleğe alınacak herhangi bir değer (örn. `MarketData`, `[News]` vb.).
    func setCache<T>(key: String, value: T) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(CacheBox(value), forKey: key as NSString)
    }

    /// Belirli bir anahtar için önbelleğe alınmış değeri getirir.
    /// - Parametre:
    ///   - key: Önbellek anahtarı.
    ///   - Returns: Beklenen türe dönüştürülmüş önbelleğe alınmış değer veya `nil`.
    func getCache<T>(key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: key as NSString)?.value as? T
    }

    /// Tüm önbelleğe alınmış değerleri temizler.
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
