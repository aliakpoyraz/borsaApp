import Foundation
import SwiftUI

public enum MarketTrend: String, Sendable {
    case strongBuy = "Güçlü Al"
    case buy = "Al"
    case neutral = "Nötr"
    case sell = "Sat"
    case strongSell = "Güçlü Sat"
    
    public var color: Color {
        switch self {
        case .strongBuy: return .green
        case .buy: return .green.opacity(0.8)
        case .neutral: return .gray
        case .sell: return .red.opacity(0.8)
        case .strongSell: return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .strongBuy: return "arrow.up.circle.fill"
        case .buy: return "arrow.up.right.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .sell: return "arrow.down.right.circle.fill"
        case .strongSell: return "arrow.down.circle.fill"
        }
    }
}

public protocol TrendServicing: Sendable {
    func calculateTrend(priceChangePercent: Decimal) -> MarketTrend
}

public final class TrendService: TrendServicing, Sendable {
    public static let shared = TrendService()
    
    public init() {}
    
    public func calculateTrend(priceChangePercent: Decimal) -> MarketTrend {
        let value = NSDecimalNumber(decimal: priceChangePercent).doubleValue
        
        if value >= 2.5 {
            return .strongBuy
        } else if value >= 0.5 {
            return .buy
        } else if value <= -2.5 {
            return .strongSell
        } else if value <= -0.5 {
            return .sell
        } else {
            return .neutral
        }
    }
}
