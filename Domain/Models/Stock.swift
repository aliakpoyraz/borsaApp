import Foundation

struct Stock: Codable, Identifiable, Hashable {
  let symbol: String
  let description: String
  let lastPrice: String
  let changePercent: String
  let volume: String

  var id: String { symbol }
}
