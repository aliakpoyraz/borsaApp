import Foundation

public protocol CryptoServicing: Sendable {
    func fetchAll24hTickers(cachePolicy: RESTClient.CachePolicy) async throws -> [Crypto]
    func fetchHistoricalPrices(symbol: String, period: String) async throws -> [Double]
}

public final class CryptoService: CryptoServicing, @unchecked Sendable {
    public static let shared = CryptoService()
    
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidEndpoint
        case requestFailed(RESTClient.Error)

        public var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Binance endpoint URL could not be constructed."
            case .requestFailed(let error):
                return error.localizedDescription
            }
        }
    }

    private let client: RESTClient
    private let endpointURL: URL?

    public init(
        client: RESTClient = RESTClient(),
        endpointURL: URL? = URL(string: "https://api.binance.com/api/v3/ticker/24hr")
    ) {
        self.client = client
        self.endpointURL = endpointURL
    }

    public func fetchAll24hTickers(cachePolicy: RESTClient.CachePolicy = .refreshIgnoringCache) async throws -> [Crypto] {
        guard let endpointURL else { throw Error.invalidEndpoint }

        let request = RESTClient.Request(
            url: endpointURL,
            method: .get,
            cachePolicy: cachePolicy
        )

        do {
            // Binance returns an array of tickers. Our `Crypto` model matches key names directly.
            return try await client.send(request, decodeTo: [Crypto].self)
        } catch let e as RESTClient.Error {
            throw Error.requestFailed(e)
        }
    }
    
    public func fetchHistoricalPrices(symbol: String, period: String) async throws -> [Double] {
        var baseSymbol = symbol.uppercased()
        if !baseSymbol.hasSuffix("USDT") {
            baseSymbol += "USDT" // Safe fallback
        }
        
        var interval = "1h"
        var limit = 24
        
        switch period {
        case "1G":
            interval = "1h"
            limit = 24
        case "1H":
            interval = "4h"
            limit = 42
        case "1A":
            interval = "1d"
            limit = 30
        case "1Y":
            interval = "1w"
            limit = 52
        case "Tümü":
            interval = "1M"
            limit = 60
        default: break
        }
        
        guard let url = URL(string: "https://api.binance.com/api/v3/klines?symbol=\(baseSymbol)&interval=\(interval)&limit=\(limit)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Response is array of arrays: [ [time, open, high, low, close, volume,...], [...] ]
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] {
            return jsonArray.compactMap { point in
                if point.count > 4, let closeStr = point[4] as? String, let closePrice = Double(closeStr) {
                    return closePrice
                } else if point.count > 4, let closePrice = point[4] as? Double {
                    return closePrice
                }
                return nil
            }
        }
        return []
    }

    // MARK: - Ranking & Sorting
    public static let popularPairs = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "BNBUSDT", "XRPUSDT", "DOGEUSDT", "AVAXUSDT", "TRXUSDT", "DOTUSDT", "LINKUSDT"]

    public static func sortCryptos(_ cryptos: [Crypto]) -> [Crypto] {
        let usdtFiltered = cryptos.filter { $0.symbol.hasSuffix("USDT") && !$0.symbol.hasSuffix("DOWNUSDT") && !$0.symbol.hasSuffix("UPUSDT") }
        return usdtFiltered.sorted {
            let s1 = $0.symbol.uppercased()
            let s2 = $1.symbol.uppercased()
            let idx1 = popularPairs.firstIndex(of: s1) ?? Int.max
            let idx2 = popularPairs.firstIndex(of: s2) ?? Int.max
            
            if idx1 != idx2 {
                return idx1 < idx2
            }
            return (Double($0.volume) ?? 0) > (Double($1.volume) ?? 0)
        }
    }
}
