import Foundation

public protocol CurrencyServicing: Sendable {
    func fetchUSDTTRYRate() async -> Decimal
}

public final class CurrencyService: CurrencyServicing, @unchecked Sendable {
    public static let shared = CurrencyService()
    
    private var cachedRate: Decimal = 32.5 // Fallback if API fails
    private var lastFetchDate: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    public init() {}
    
    public func fetchUSDTTRYRate() async -> Decimal {
        if let last = lastFetchDate, Date().timeIntervalSince(last) < cacheTTL {
            return cachedRate
        }
        
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=USDTTRY") else {
            return cachedRate
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
               let priceStr = json["price"],
               let price = Decimal(string: priceStr) {
                self.cachedRate = price
                self.lastFetchDate = Date()
                return price
            }
        } catch {
            print("CurrencyService error: \(error)")
        }
        
        return cachedRate
    }
}
