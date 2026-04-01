struct Crypto: Codable, Identifiable, Hashable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
    let highPrice: String
    let lowPrice: String
    let volume: String

    var id: String { symbol }
}
