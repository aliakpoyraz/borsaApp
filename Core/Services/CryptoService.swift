import Foundation

public protocol CryptoServicing: Sendable {
    func fetchAll24hTickers(cachePolicy: RESTClient.CachePolicy) async -> [Crypto]
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
                return error.turkishDescription
            }
        }
    }

    private let client: RESTClient
    private let endpointURL: URL?
    private let cacheKey = "cachedLength24hTickers"
    private let cacheDateKey = "cachedLength24hTickersDate"
    private let userDefaults = UserDefaults.standard

    // Ana kripto paralar - İnternet yokken arama veya ilk açılış için kullanılır
    private let knownCryptos: [(symbol: String, name: String)] = [
        ("BTCUSDT", "Bitcoin"),
        ("ETHUSDT", "Ethereum"),
        ("BNBUSDT", "BNB"),
        ("SOLUSDT", "Solana"),
        ("XRPUSDT", "XRP"),
        ("ADABUSD", "Cardano"),
        ("AVAXUSDT", "Avalanche"),
        ("DOTUSDT", "Polkadot"),
        ("MATICUSDT", "Polygon"),
        ("DOGEUSDT", "Dogecoin"),
        ("TRXUSDT", "TRON"),
        ("LINKUSDT", "Chainlink")
    ]

    public init(
        client: RESTClient = RESTClient(),
        endpointURL: URL? = URL(string: "https://api.binance.com/api/v3/ticker/24hr")
    ) {
        self.client = client
        self.endpointURL = endpointURL
    }

    public func fetchAll24hTickers(cachePolicy: RESTClient.CachePolicy = .refreshIgnoringCache) async -> [Crypto] {
        guard let endpointURL else {
            return loadFromCache() ?? []
        }

        let request = RESTClient.Request(
            url: endpointURL,
            method: .get,
            cachePolicy: cachePolicy
        )

        do {
            // Ağ üzerinden veriyi çekmeye çalış (Binance 24h ticker listesi)
            let fetched = try await client.send(request, decodeTo: [Crypto].self)
            
            // Başarılı olursa yerel depoya kaydet
            saveToCache(fetched)
            return fetched
            
        } catch {
            print("CryptoService: Ağ verisi çekilemedi, yerel cache kontrol ediliyor...")
            
            // Ağ hatası durumunda yerel depodan (UserDefaults) veriyi oku
            if let cached = loadFromCache() {
                return cached
            }
            
            // Hiç veri yoksa bilinen kripto listesinden yer tutucuları oluştur
            return knownCryptos.map {
                Crypto(
                    symbol: $0.symbol,
                    lastPrice: "0",
                    priceChangePercent: "0",
                    highPrice: "0",
                    lowPrice: "0",
                    volume: "0"
                )
            }
        }
    }
    
    // MARK: - Yerel Önbellek (Local Cache)
    
    private func saveToCache(_ cryptos: [Crypto]) {
        do {
            let data = try JSONEncoder().encode(cryptos)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: cacheDateKey)
        } catch {
            print("CryptoService: Cache kaydetme hatası: \(error)")
        }
    }

    private func loadFromCache() -> [Crypto]? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        do {
            return try JSONDecoder().decode([Crypto].self, from: data)
        } catch {
            print("CryptoService: Cache okuma hatası: \(error)")
            return nil
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
        
        let mirrorHosts = [
            "api.binance.com",
            "api.binance.me",
            "api1.binance.com",
            "api2.binance.com",
            "api3.binance.com",
            "api-gcp.binance.com"
        ]
        
        var lastError: Swift.Error?
        
        for host in mirrorHosts {
            guard let url = URL(string: "https://\(host)/api/v3/klines?symbol=\(baseSymbol)&interval=\(interval)&limit=\(limit)") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 5.0 // Mobil veride hızlıca diğerine geçmek için düşük zaman aşımı
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
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
                }
            } catch {
                lastError = error
                continue
            }
        }
        
        if let lastError {
            throw lastError
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
