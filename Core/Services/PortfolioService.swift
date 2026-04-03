import Foundation
import Combine

public protocol PortfolioServicing: Sendable {
    func getAssets() async -> [PortfolioAsset]
    func getAssetsWithValue() async throws -> [PortfolioAssetPnL]

    func buy(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws
    func sell(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws
    func updateQuantity(kind: PortfolioAssetKind, symbol: String, newQuantity: Decimal) async throws

    func startLivePrices() async
    func subscribeCryptoLivePrices(symbols: [String]) async
    
    var priceUpdatePublisher: AnyPublisher<(symbol: String, price: Decimal, percent: Decimal?), Never> { get }
}

@MainActor
public final class PortfolioService: PortfolioServicing, @unchecked Sendable {
    private let priceUpdateSubject = PassthroughSubject<(symbol: String, price: Decimal, percent: Decimal?), Never>()
    
    public var priceUpdatePublisher: AnyPublisher<(symbol: String, price: Decimal, percent: Decimal?), Never> {
        priceUpdateSubject.eraseToAnyPublisher()
    }
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidSymbol
        case invalidQuantity
        case priceUnavailable
        case insufficientQuantity(requested: Decimal, available: Decimal)
        case syncError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidSymbol: return "Geçersiz sembol."
            case .invalidQuantity: return "Miktar 0'dan büyük olmalı."
            case .priceUnavailable: return "Güncel fiyat alınamadı."
            case .insufficientQuantity(let req, let avail): return "Yetersiz miktar. İstenen: \(req), Mevcut: \(avail)."
            case .syncError(let msg): return "Bulut Senkronizasyon Hatası: \(msg)"
            }
        }
    }

    // Dependencies
    private let bistService: BistServicing
    private let cryptoService: CryptoServicing
    private let webSocketClient: WebSocketClienting
    private let now: @Sendable () -> Date

    // In-memory
    private var priceCache: [String: (price: Decimal, percent: Decimal?, updatedAt: Date?)] = [:]
    private var localAssetsCache: [PortfolioAsset] = []
    private var livePriceTask: Task<Void, Never>?

    public init(
        bistService: BistServicing,
        cryptoService: CryptoServicing,
        webSocketClient: WebSocketClienting,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.bistService = bistService
        self.cryptoService = cryptoService
        self.webSocketClient = webSocketClient
        self.now = now
    }

    private static let _shared = PortfolioService(
        bistService: BistService.shared,
        cryptoService: CryptoService.shared,
        webSocketClient: WebSocketClient.shared
    )

    public static func live(now: @escaping @Sendable () -> Date = { Date() }) -> PortfolioService {
        _shared
    }

    public static var shared: PortfolioService { _shared }

    deinit {
        livePriceTask?.cancel()
    }

    // MARK: - Token Management

    /// Returns current access token, auto-refreshing if expired (401).
    private func validToken() async -> String {
        let token = UserDefaults.standard.string(forKey: "supabaseAccessToken") ?? ""
        return token
    }

    private func getAccessToken() -> String {
        return UserDefaults.standard.string(forKey: "supabaseAccessToken") ?? ""
    }

    /// Makes an authenticated request, auto-retrying once if 401 (JWT expired).
    private func authenticatedData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var req = request
        let token = getAccessToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: req)
        let httpRes = response as! HTTPURLResponse

        if httpRes.statusCode == 401 {
            // Token expired — try refresh
            if let newToken = await AuthManager.shared.refreshTokenIfNeeded() {
                var retryReq = req
                retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryReq)
                return (retryData, retryResponse as! HTTPURLResponse)
            } else {
                throw Error.syncError("Oturumunuz sona erdi. Lütfen tekrar giriş yapın.")
            }
        }
        return (data, httpRes)
    }

    public func getAssets() async -> [PortfolioAsset] {
        let token = getAccessToken()
        guard !token.isEmpty else { return [] }
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/portfolio_assets?select=*") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, httpRes) = try await authenticatedData(for: request)
            if httpRes.statusCode == 200,
               let jsonObjects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var assets: [PortfolioAsset] = []
                for row in jsonObjects {
                    if let kindStr = row["kind"] as? String,
                       let symbol = row["symbol"] as? String,
                       let quantityDouble = row["quantity"] as? Double {
                        let kind: PortfolioAssetKind = kindStr == "crypto" ? .crypto : .stock
                        assets.append(PortfolioAsset(
                            kind: kind,
                            symbol: symbol,
                            quantity: Decimal(quantityDouble)
                        ))
                    }
                }
                self.localAssetsCache = assets
                return assets
            }
        } catch {
            print("Portfolio fetch error: \(error.localizedDescription)")
        }
        return self.localAssetsCache
    }

    public func getAssetsWithValue() async throws -> [PortfolioAssetPnL] {
        let assets = await getAssets()
        var result: [PortfolioAssetPnL] = []
        result.reserveCapacity(assets.count)
        
        let cryptoSymbols = assets.filter { $0.kind == .crypto }.map { $0.symbol }
        if !cryptoSymbols.isEmpty {
            await subscribeCryptoLivePrices(symbols: cryptoSymbols)
        }

        for asset in assets {
            var current = hitCacheOrFallback(for: asset.kind, symbol: asset.symbol)
            if current.price == 0 {
                current = (try? await currentPrice(for: asset.kind, symbol: asset.symbol, forceRefresh: true)) ?? (0, nil)
            } else {
                // Periodically force refresh stocks that don't have websocket updates
                if asset.kind == .stock {
                    current = (try? await currentPrice(for: asset.kind, symbol: asset.symbol, forceRefresh: true)) ?? current
                }
            }
            result.append(PortfolioAssetPnL(
                symbol: asset.symbol,
                kind: asset.kind,
                quantity: asset.quantity,
                currentPrice: current.price,
                currentChangePercent: current.percent
            ))
        }
        return result
    }

    public func buy(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws {
        let symbol = normalize(symbol)
        guard !symbol.isEmpty else { throw Error.invalidSymbol }
        guard quantity > 0 else { throw Error.invalidQuantity }

        let existingAsset = self.localAssetsCache.first { $0.kind == kind && $0.symbol == symbol }
        let newQty = (existingAsset?.quantity ?? 0) + quantity

        try await syncPortfolioAsset(kind: kind, symbol: symbol, quantity: newQty)
        self.localAssetsCache = [] // Clear cache to force refresh
    }

    public func updateQuantity(kind: PortfolioAssetKind, symbol: String, newQuantity: Decimal) async throws {
        let symbol = normalize(symbol)
        guard !symbol.isEmpty else { throw Error.invalidSymbol }
        guard newQuantity >= 0 else { throw Error.invalidQuantity }
        
        if newQuantity == 0 {
            try await deletePortfolioAsset(kind: kind, symbol: symbol)
        } else {
            try await syncPortfolioAsset(kind: kind, symbol: symbol, quantity: newQuantity)
        }
        self.localAssetsCache = [] // Clear cache to force refresh
    }

    public func sell(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws {
        let symbol = normalize(symbol)
        guard !symbol.isEmpty else { throw Error.invalidSymbol }
        guard quantity > 0 else { throw Error.invalidQuantity }

        guard let existing = self.localAssetsCache.first(where: { $0.kind == kind && $0.symbol == symbol }) else {
            throw Error.insufficientQuantity(requested: quantity, available: 0)
        }

        guard existing.quantity >= quantity else {
            throw Error.insufficientQuantity(requested: quantity, available: existing.quantity)
        }

        let newQty = existing.quantity - quantity
        
        if newQty <= 0 {
            try await deletePortfolioAsset(kind: kind, symbol: symbol)
        } else {
            try await syncPortfolioAsset(kind: kind, symbol: symbol, quantity: newQty)
        }
        self.localAssetsCache = [] // Clear cache to force refresh
    }
    
    // MARK: - Supabase Sync (Private)
    
    private func syncPortfolioAsset(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws {
        guard !getAccessToken().isEmpty else { throw Error.syncError("Giriş yapmanız gerekiyor") }

        let qDouble = NSDecimalNumber(decimal: quantity).doubleValue

        // Simplified body: ONLY sending what is in your database (symbol, kind, quantity)
        let body: [String: Any] = [
            "symbol": symbol.uppercased(),
            "kind": kind.rawValue,
            "quantity": qDouble
        ]
        let bodyData = try? JSONSerialization.data(withJSONObject: body)

        // PostgREST Upsert using 'on_conflict'
        let urlStr = "\(SupabaseConfig.supabaseURL)/rest/v1/portfolio_assets?on_conflict=user_id,symbol,kind"
        guard let url = URL(string: urlStr) else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = bodyData

        let (data, httpRes) = try await authenticatedData(for: req)
        if httpRes.statusCode >= 400 {
            let errBody = String(data: data, encoding: .utf8) ?? ""
            print("Portfolio Sync Error: \(errBody)")
            throw Error.syncError("Varlık senkronizasyon hatası (\(httpRes.statusCode)): \(errBody)")
        }

        // Update local cache
        let normalizedSym = symbol.uppercased()
        if let idx = self.localAssetsCache.firstIndex(where: { $0.symbol == normalizedSym && $0.kind == kind }) {
            self.localAssetsCache[idx].quantity = quantity
        } else {
            self.localAssetsCache.append(PortfolioAsset(kind: kind, symbol: normalizedSym, quantity: quantity))
        }
    }

    private func deletePortfolioAsset(kind: PortfolioAssetKind, symbol: String) async throws {
        guard !getAccessToken().isEmpty else { return }
        let urlStr = "\(SupabaseConfig.supabaseURL)/rest/v1/portfolio_assets?symbol=eq.\(symbol)&kind=eq.\(kind.rawValue)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        let (_, httpRes) = try await authenticatedData(for: req)
        if httpRes.statusCode >= 400 {
            throw Error.syncError("Silme başarısız: \(httpRes.statusCode)")
        }
        self.localAssetsCache.removeAll(where: { $0.symbol == symbol && $0.kind == kind })
    }

    // MARK: - Live Prices

    private var cancellables = Set<AnyCancellable>()

    public func startLivePrices() async {
        webSocketClient.pricePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tick in
                self?.ingestCryptoTick(tick)
            }
            .store(in: &cancellables)
            
        await webSocketClient.connect()
    }

    public func subscribeCryptoLivePrices(symbols: [String]) async {
        await startLivePrices()
        await webSocketClient.subscribe(symbols: symbols)
    }

    // MARK: - Internals

    private func currentPrice(for kind: PortfolioAssetKind, symbol: String, forceRefresh: Bool = false) async throws -> (price: Decimal, percent: Decimal?) {
        let symbol = normalize(symbol)
        let cacheKey = cacheKeyFor(kind: kind, symbol: symbol)

        if !forceRefresh, let cached = priceCache[cacheKey] { return (cached.price, cached.percent) }

        switch kind {
        case .stock:
            let searchResults = await bistService.searchStocks(query: symbol)
            if let match = searchResults.first(where: { normalize($0.symbol) == symbol }) {
                guard let price = DecimalParser.parse(match.lastPrice) else { throw Error.priceUnavailable }
                let percent = DecimalParser.parse(match.changePercent.replacingOccurrences(of: "%", with: ""))
                priceCache[cacheKey] = (price, percent, now())
                return (price, percent)
            }
            
            // Fallback to popular list
            let stocks = await bistService.fetchStocks(forceRefresh: forceRefresh)
            if let match = stocks.first(where: { normalize($0.symbol) == symbol }) {
                guard let price = DecimalParser.parse(match.lastPrice) else { throw Error.priceUnavailable }
                let percent = DecimalParser.parse(match.changePercent.replacingOccurrences(of: "%", with: ""))
                priceCache[cacheKey] = (price, percent, now())
                return (price, percent)
            }
            throw Error.priceUnavailable

        case .crypto:
            let tickers = try await cryptoService.fetchAll24hTickers(cachePolicy: forceRefresh ? .refreshIgnoringCache : .useCacheIfAvailable)
            guard let match = tickers.first(where: { normalize($0.symbol) == symbol }) else { throw Error.priceUnavailable }
            guard let price = DecimalParser.parse(match.lastPrice) else { throw Error.priceUnavailable }
            let percent = DecimalParser.parse(match.priceChangePercent)
            priceCache[cacheKey] = (price, percent, now())
            return (price, percent)
        }
    }
    
    private func hitCacheOrFallback(for kind: PortfolioAssetKind, symbol: String) -> (price: Decimal, percent: Decimal?) {
        let key = cacheKeyFor(kind: kind, symbol: normalize(symbol))
        if let cached = priceCache[key] {
            return (cached.price, cached.percent)
        }
        return (0, nil)
    }

    private func ingestCryptoTick(_ tick: WebSocketPriceTick) {
        let symbol = normalize(tick.symbol)
        guard let price = DecimalParser.parse(tick.price) else { return }
        let percent = tick.priceChangePercent.flatMap { DecimalParser.parse($0) }
        
        let key = cacheKeyFor(kind: .crypto, symbol: symbol)
        priceCache[key] = (price, percent, tick.eventTime ?? now())
        
        // Emit update to publisher
        priceUpdateSubject.send((symbol: symbol, price: price, percent: percent))
    }

    private func normalize(_ symbol: String) -> String { symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private func cacheKeyFor(kind: PortfolioAssetKind, symbol: String) -> String { "\(kind.rawValue):\(normalize(symbol))" }
}

private enum DecimalParser {
    static func parse(_ string: String) -> Decimal? {
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

// Decimal Overrides
private extension Decimal {
    static func + (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs, r = rhs, result = Decimal()
        NSDecimalAdd(&result, &l, &r, .bankers)
        return result
    }
    static func - (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs, r = rhs, result = Decimal()
        NSDecimalSubtract(&result, &l, &r, .bankers)
        return result
    }
    static func * (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs, r = rhs, result = Decimal()
        NSDecimalMultiply(&result, &l, &r, .bankers)
        return result
    }
    static func / (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs, r = rhs, result = Decimal()
        NSDecimalDivide(&result, &l, &r, .bankers)
        return result
    }
}
