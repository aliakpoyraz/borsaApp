import Foundation

public protocol PortfolioServicing: Sendable {
    var initialBalance: Decimal { get }

    func getBalance() async -> Decimal
    func getAssets() async -> [PortfolioAsset]
    func getAssetsWithPnL() async throws -> [PortfolioAssetPnL]

    func buy(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws
    func sell(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws

    /// Starts listening live price stream (crypto). Safe to call multiple times.
    func startLivePrices() async

    /// Subscribes websocket for given crypto symbols (e.g. "btcusdt").
    func subscribeCryptoLivePrices(symbols: [String]) async

    /// Debug / dev convenience.
    func resetToInitialState() async
}

public actor PortfolioService: PortfolioServicing {
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidSymbol
        case invalidQuantity
        case priceUnavailable
        case insufficientBalance(required: Decimal, available: Decimal)
        case insufficientQuantity(requested: Decimal, available: Decimal)

        public var errorDescription: String? {
            switch self {
            case .invalidSymbol:
                return "Symbol is invalid."
            case .invalidQuantity:
                return "Quantity must be greater than zero."
            case .priceUnavailable:
                return "Current price is unavailable."
            case .insufficientBalance(let required, let available):
                return "Insufficient balance. Required: \(required), available: \(available)."
            case .insufficientQuantity(let requested, let available):
                return "Insufficient quantity. Requested: \(requested), available: \(available)."
            }
        }
    }

    // MARK: - Public

    public let initialBalance: Decimal

    // MARK: - Dependencies

    private let bistService: BistServicing
    private let cryptoService: CryptoServicing
    private let webSocketClient: WebSocketClienting
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    // MARK: - Storage keys

    private let balanceKey = "portfolio.balance.v1"
    private let assetsKey = "portfolio.assets.v1"
    private let initializedKey = "portfolio.initialized.v1"

    // MARK: - In-memory

    private var priceCache: [String: (price: Decimal, updatedAt: Date?)] = [:] // key: "<kind>:<symbol>"
    private var livePriceTask: Task<Void, Never>?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        initialBalance: Decimal = 100_000,
        bistService: BistServicing = BistService(),
        cryptoService: CryptoServicing = CryptoService(),
        webSocketClient: WebSocketClienting = WebSocketClient(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.initialBalance = initialBalance
        self.bistService = bistService
        self.cryptoService = cryptoService
        self.webSocketClient = webSocketClient
        self.defaults = defaults
        self.now = now

        bootstrapIfNeeded()
    }

    deinit {
        livePriceTask?.cancel()
    }

    // MARK: - API

    public func getBalance() async -> Decimal {
        loadBalance()
    }

    public func getAssets() async -> [PortfolioAsset] {
        loadAssets()
    }

    public func getAssetsWithPnL() async throws -> [PortfolioAssetPnL] {
        let assets = loadAssets()
        var result: [PortfolioAssetPnL] = []
        result.reserveCapacity(assets.count)

        for asset in assets {
            let current = try await currentPrice(for: asset.kind, symbol: asset.symbol)
            let pnl = makePnL(asset: asset, currentPrice: current)
            result.append(pnl)
        }
        return result
    }

    public func buy(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws {
        let symbol = normalize(symbol)
        guard !symbol.isEmpty else { throw Error.invalidSymbol }
        guard quantity > 0 else { throw Error.invalidQuantity }

        let price = try await currentPrice(for: kind, symbol: symbol)
        let cost = price * quantity

        var balance = loadBalance()
        guard balance >= cost else { throw Error.insufficientBalance(required: cost, available: balance) }

        var assets = loadAssets()
        if let idx = assets.firstIndex(where: { $0.kind == kind && $0.symbol == symbol }) {
            var existing = assets[idx]
            let oldQty = existing.quantity
            let newQty = oldQty + quantity
            let weightedAvg = (existing.averageBuyPrice * oldQty + price * quantity) / newQty

            existing.quantity = newQty
            existing.averageBuyPrice = weightedAvg
            existing.lastKnownPrice = price
            existing.lastUpdatedAt = now()
            assets[idx] = existing
        } else {
            assets.append(
                PortfolioAsset(
                    kind: kind,
                    symbol: symbol,
                    quantity: quantity,
                    averageBuyPrice: price,
                    lastKnownPrice: price,
                    lastUpdatedAt: now()
                )
            )
        }

        balance -= cost
        storeBalance(balance)
        storeAssets(assets)
    }

    public func sell(kind: PortfolioAssetKind, symbol: String, quantity: Decimal) async throws {
        let symbol = normalize(symbol)
        guard !symbol.isEmpty else { throw Error.invalidSymbol }
        guard quantity > 0 else { throw Error.invalidQuantity }

        let price = try await currentPrice(for: kind, symbol: symbol)
        let proceeds = price * quantity

        var assets = loadAssets()
        guard let idx = assets.firstIndex(where: { $0.kind == kind && $0.symbol == symbol }) else {
            throw Error.insufficientQuantity(requested: quantity, available: 0)
        }

        var existing = assets[idx]
        guard existing.quantity >= quantity else {
            throw Error.insufficientQuantity(requested: quantity, available: existing.quantity)
        }

        existing.quantity -= quantity
        existing.lastKnownPrice = price
        existing.lastUpdatedAt = now()

        if existing.quantity == 0 {
            assets.remove(at: idx)
        } else {
            assets[idx] = existing
        }

        var balance = loadBalance()
        balance += proceeds
        storeBalance(balance)
        storeAssets(assets)
    }

    public func startLivePrices() async {
        if livePriceTask != nil { return }

        livePriceTask = Task { [weak self] in
            guard let self else { return }
            await self.webSocketClient.connect()

            for await tick in self.webSocketClient.priceStream {
                await self.ingestCryptoTick(tick)
                if Task.isCancelled { return }
            }
        }
    }

    public func subscribeCryptoLivePrices(symbols: [String]) async {
        await startLivePrices()
        await webSocketClient.subscribe(symbols: symbols)
    }

    public func resetToInitialState() async {
        defaults.removeObject(forKey: initializedKey)
        defaults.removeObject(forKey: balanceKey)
        defaults.removeObject(forKey: assetsKey)
        priceCache.removeAll()
        bootstrapIfNeeded()
    }

    // MARK: - Internals

    private func bootstrapIfNeeded() {
        if defaults.bool(forKey: initializedKey) { return }
        defaults.set(true, forKey: initializedKey)
        storeBalance(initialBalance)
        storeAssets([])
    }

    private func loadBalance() -> Decimal {
        if let data = defaults.data(forKey: balanceKey),
           let value = try? decoder.decode(DecimalCodableBox.self, from: data)
        {
            return value.value
        }
        return initialBalance
    }

    private func storeBalance(_ value: Decimal) {
        let box = DecimalCodableBox(value)
        if let data = try? encoder.encode(box) {
            defaults.set(data, forKey: balanceKey)
        }
    }

    private func loadAssets() -> [PortfolioAsset] {
        guard let data = defaults.data(forKey: assetsKey) else { return [] }
        return (try? decoder.decode([PortfolioAsset].self, from: data)) ?? []
    }

    private func storeAssets(_ assets: [PortfolioAsset]) {
        if let data = try? encoder.encode(assets) {
            defaults.set(data, forKey: assetsKey)
        }
    }

    private func currentPrice(for kind: PortfolioAssetKind, symbol: String) async throws -> Decimal {
        let symbol = normalize(symbol)
        let cacheKey = cacheKeyFor(kind: kind, symbol: symbol)

        if let cached = priceCache[cacheKey]?.price {
            return cached
        }

        switch kind {
        case .stock:
            let stocks = await bistService.fetchStocks()
            guard let match = stocks.first(where: { normalize($0.symbol) == symbol }) else {
                throw Error.priceUnavailable
            }
            guard let price = DecimalParser.parse(match.lastPrice) else { throw Error.priceUnavailable }
            priceCache[cacheKey] = (price, now())
            return price

        case .crypto:
            let tickers = try await cryptoService.fetchAll24hTickers(cachePolicy: .useCacheIfAvailable)
            guard let match = tickers.first(where: { normalize($0.symbol) == symbol }) else {
                throw Error.priceUnavailable
            }
            guard let price = DecimalParser.parse(match.lastPrice) else { throw Error.priceUnavailable }
            priceCache[cacheKey] = (price, now())
            return price
        }
    }

    private func ingestCryptoTick(_ tick: WebSocketPriceTick) async {
        let symbol = normalize(tick.symbol)
        guard let price = DecimalParser.parse(tick.price) else { return }

        let key = cacheKeyFor(kind: .crypto, symbol: symbol)
        priceCache[key] = (price, tick.eventTime ?? now())

        var assets = loadAssets()
        var changed = false
        for i in assets.indices {
            guard assets[i].kind == .crypto, normalize(assets[i].symbol) == symbol else { continue }
            assets[i].lastKnownPrice = price
            assets[i].lastUpdatedAt = tick.eventTime ?? now()
            changed = true
        }
        if changed {
            storeAssets(assets)
        }
    }

    private func makePnL(asset: PortfolioAsset, currentPrice: Decimal) -> PortfolioAssetPnL {
        let diff = currentPrice - asset.averageBuyPrice
        let amount = diff * asset.quantity
        let percent: Decimal
        if asset.averageBuyPrice == 0 {
            percent = 0
        } else {
            percent = (diff / asset.averageBuyPrice) * 100
        }

        return PortfolioAssetPnL(
            symbol: asset.symbol,
            kind: asset.kind,
            quantity: asset.quantity,
            averageBuyPrice: asset.averageBuyPrice,
            currentPrice: currentPrice,
            profitLossAmount: amount,
            profitLossPercent: percent
        )
    }

    private func normalize(_ symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func cacheKeyFor(kind: PortfolioAssetKind, symbol: String) -> String {
        "\(kind.rawValue):\(normalize(symbol))"
    }
}

// MARK: - Codable helpers

private struct DecimalCodableBox: Codable, Sendable {
    let value: Decimal
    init(_ value: Decimal) { self.value = value }
}

private enum DecimalParser {
    static func parse(_ string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Accept "312.40" and also tolerate commas in case UI formats it.
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")

        // Locale-independent Decimal parsing
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

// MARK: - Decimal arithmetic

private extension Decimal {
    static func + (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs
        var r = rhs
        var result = Decimal()
        NSDecimalAdd(&result, &l, &r, .bankers)
        return result
    }

    static func - (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs
        var r = rhs
        var result = Decimal()
        NSDecimalSubtract(&result, &l, &r, .bankers)
        return result
    }

    static func * (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs
        var r = rhs
        var result = Decimal()
        NSDecimalMultiply(&result, &l, &r, .bankers)
        return result
    }

    static func / (lhs: Decimal, rhs: Decimal) -> Decimal {
        var l = lhs
        var r = rhs
        var result = Decimal()
        NSDecimalDivide(&result, &l, &r, .bankers)
        return result
    }
}

