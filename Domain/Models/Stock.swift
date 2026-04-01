import Foundation

public struct Stock: Codable, Identifiable, Hashable, Sendable {
  public let symbol: String
  public let description: String
  public let lastPrice: String
  public let changePercent: String
  public let volume: String

  public var id: String { symbol }

  public init(symbol: String, description: String, lastPrice: String, changePercent: String, volume: String) {
    self.symbol = symbol
    self.description = description
    self.lastPrice = lastPrice
    self.changePercent = changePercent
    self.volume = volume
  }
}
