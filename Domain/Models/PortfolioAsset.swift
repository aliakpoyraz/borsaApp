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

    /// Volume-weighted average buy price for the current open position.
    public var averageBuyPrice: Decimal

    /// Last price observed by the portfolio service (REST / websocket).
    public var lastKnownPrice: Decimal?
    public var lastUpdatedAt: Date?

    public var id: String { "\(kind.rawValue):\(symbol.uppercased())" }

    public init(
        kind: PortfolioAssetKind,
        symbol: String,
        quantity: Decimal,
        averageBuyPrice: Decimal,
        lastKnownPrice: Decimal? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.kind = kind
        self.symbol = symbol.uppercased()
        self.quantity = quantity
        self.averageBuyPrice = averageBuyPrice
        self.lastKnownPrice = lastKnownPrice
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public struct PortfolioAssetPnL: Codable, Sendable, Hashable {
    public let symbol: String
    public let kind: PortfolioAssetKind

    public let quantity: Decimal
    public let averageBuyPrice: Decimal
    public let currentPrice: Decimal

    public let profitLossAmount: Decimal
    public let profitLossPercent: Decimal
}

