public struct Crypto: Codable, Identifiable, Hashable, Sendable {
    public let symbol: String
    public let lastPrice: String
    public let priceChangePercent: String
    public let highPrice: String
    public let lowPrice: String
    public let volume: String

    public var id: String { symbol }

    public init(
        symbol: String,
        lastPrice: String,
        priceChangePercent: String,
        highPrice: String,
        lowPrice: String,
        volume: String
    ) {
        self.symbol = symbol
        self.lastPrice = lastPrice
        self.priceChangePercent = priceChangePercent
        self.highPrice = highPrice
        self.lowPrice = lowPrice
        self.volume = volume
    }
}
