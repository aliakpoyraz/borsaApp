public struct Crypto: Codable, Identifiable, Hashable, Sendable {
    public let symbol: String
    public let lastPrice: String
    public let priceChangePercent: String
    public let priceChange: String
    public let highPrice: String
    public let lowPrice: String
    public let volume: String
    public let quoteVolume: String

    public var id: String { symbol }

    enum CodingKeys: String, CodingKey {
        case symbol
        case lastPrice
        case priceChangePercent
        case priceChange
        case highPrice
        case lowPrice
        case volume
        case quoteVolume
    }

    public init(
        symbol: String,
        lastPrice: String,
        priceChangePercent: String,
        priceChange: String = "0",
        highPrice: String,
        lowPrice: String,
        volume: String,
        quoteVolume: String = "0"
    ) {
        self.symbol = symbol
        self.lastPrice = lastPrice
        self.priceChangePercent = priceChangePercent
        self.priceChange = priceChange
        self.highPrice = highPrice
        self.lowPrice = lowPrice
        self.volume = volume
        self.quoteVolume = quoteVolume
    }
}
