import Foundation

public struct Stock: Codable, Identifiable, Hashable, Sendable {
  public let symbol: String
  public let description: String
  public let lastPrice: String
  public let changePercent: String
  public let volume: String
  public let highPrice: String
  public let lowPrice: String
  
  // Financial Ratios (from Yahoo Finance)
  public let marketCap: String?
  public let peRatio: String?
  public let pddRatio: String?
  public let dividendYield: String?

  public var id: String { symbol }

  public init(
    symbol: String, 
    description: String, 
    lastPrice: String, 
    changePercent: String, 
    volume: String, 
    highPrice: String = "—", 
    lowPrice: String = "—",
    marketCap: String? = nil,
    peRatio: String? = nil,
    pddRatio: String? = nil,
    dividendYield: String? = nil
  ) {
    self.symbol = symbol
    self.description = description
    self.lastPrice = lastPrice
    self.changePercent = changePercent
    self.volume = volume
    self.highPrice = highPrice
    self.lowPrice = lowPrice
    self.marketCap = marketCap
    self.peRatio = peRatio
    self.pddRatio = pddRatio
    self.dividendYield = dividendYield
  }
}
