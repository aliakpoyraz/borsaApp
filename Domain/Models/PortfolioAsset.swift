import Foundation

public enum PortfolioAssetKind: String, Codable, Sendable, Hashable {
    case stock
    case crypto
}

public struct PortfolioAsset: Codable, Identifiable, Hashable, Sendable {
    public let kind: PortfolioAssetKind
    public let symbol: String

    /// Total position size.
    public var quantity: Decimal

    /// Last price observed by the portfolio service (REST / websocket).
    public var lastKnownPrice: Decimal?
    public var lastUpdatedAt: Date?

    public var id: String { "\(kind.rawValue):\(symbol.uppercased())" }

    public init(
        kind: PortfolioAssetKind,
        symbol: String,
        quantity: Decimal,
        lastKnownPrice: Decimal? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.kind = kind
        self.symbol = symbol.uppercased()
        self.quantity = quantity
        self.lastKnownPrice = lastKnownPrice
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public struct PortfolioAssetPnL: Codable, Identifiable, Sendable, Hashable {
    public var id: String { symbol }
    public let symbol: String
    public let kind: PortfolioAssetKind

    public let quantity: Decimal
    public let currentPrice: Decimal
    public let currentChangePercent: Decimal?

    public var totalValue: Decimal { quantity * currentPrice }
    
    public func totalValueTL(rate: Decimal) -> Decimal {
        if kind == .crypto {
            return totalValue * rate
        }
        return totalValue
    }
}

