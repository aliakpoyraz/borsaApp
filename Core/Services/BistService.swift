import Foundation

protocol BistServicing: Sendable {
    /// Returns BIST stocks using the "15 minute rule" (in-memory cache).
    func fetchStocks() async -> [Stock]
}

/// Mock BIST service (school-project friendly).
/// - Note: Uses an in-memory cache with a 15 minute TTL.
final class BistService: BistServicing, @unchecked Sendable {
    private let ttl: TimeInterval = 15 * 60
    private let now: @Sendable () -> Date

    private var cachedAt: Date?
    private var cachedStocks: [Stock]?

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    func fetchStocks() async -> [Stock] {
        if
            let cachedAt,
            let cachedStocks,
            now().timeIntervalSince(cachedAt) <= ttl
        {
            return cachedStocks
        }

        let fresh = makeMockStocks()
        cachedAt = now()
        cachedStocks = fresh
        return fresh
    }

    private func makeMockStocks() -> [Stock] {
        [
            Stock(symbol: "THYAO", description: "Türk Hava Yolları", lastPrice: "312.40", changePercent: "+1.85%", volume: "3.2M"),
            Stock(symbol: "ASELS", description: "Aselsan", lastPrice: "58.15", changePercent: "-0.40%", volume: "5.6M"),
            Stock(symbol: "EREGL", description: "Ereğli Demir ve Çelik", lastPrice: "42.02", changePercent: "+0.95%", volume: "7.1M"),
            Stock(symbol: "KCHOL", description: "Koç Holding", lastPrice: "173.20", changePercent: "+0.30%", volume: "1.4M"),
            Stock(symbol: "GARAN", description: "Garanti BBVA", lastPrice: "83.75", changePercent: "-1.10%", volume: "9.8M"),
            Stock(symbol: "SAHOL", description: "Sabancı Holding", lastPrice: "92.10", changePercent: "+0.55%", volume: "2.1M"),
            Stock(symbol: "TUPRS", description: "Tüpraş", lastPrice: "205.60", changePercent: "+2.05%", volume: "1.0M"),
            Stock(symbol: "BIMAS", description: "BİM Mağazalar", lastPrice: "356.90", changePercent: "-0.15%", volume: "0.8M")
        ]
    }
}
