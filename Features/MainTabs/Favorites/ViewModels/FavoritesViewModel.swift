import Foundation
import Combine
import SwiftUI

@MainActor
public final class FavoritesViewModel: ObservableObject {
    @Published public private(set) var favoriteCryptos: [Crypto] = []
    @Published public private(set) var favoriteStocks: [Stock] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isConnected: Bool = true
    
    private let cryptoService: CryptoServicing
    private let bistService: BistServicing
    private let webSocketClient: WebSocketClienting
    private var cancellables = Set<AnyCancellable>()
    
    private var liveStateTask: Task<Void, Never>?
    private var subscribeTask: Task<Void, Never>?
    
    public init(
        cryptoService: CryptoServicing? = nil,
        bistService: BistServicing? = nil,
        webSocketClient: WebSocketClienting? = nil
    ) {
        self.cryptoService = cryptoService ?? CryptoService.shared
        self.bistService = bistService ?? BistService.shared
        self.webSocketClient = webSocketClient ?? WebSocketClient.shared
        
        FavoritesManager.shared.$favoriteCryptoSymbols
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadData() }
            }
            .store(in: &cancellables)
            
        FavoritesManager.shared.$favoriteStockSymbols
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadData() }
            }
            .store(in: &cancellables)
            
        listenToNetworkState()
        setupLivePrices()
    }
    
    private func setupLivePrices() {
        webSocketClient.pricePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tick in
                self?.updateCryptoPrice(tick)
            }
            .store(in: &cancellables)
    }
    
    public func loadData() async {
        isLoading = true
        
        do {
            async let cryptosTask = cryptoService.fetchAll24hTickers(cachePolicy: .useCacheIfAvailable)
            async let stocksTask = bistService.fetchStocks(forceRefresh: false)
            
            let (fetchedCryptos, fetchedStocks) = try await (cryptosTask, stocksTask)
            
            let cryptoFavs = FavoritesManager.shared.favoriteCryptoSymbols
            let stockFavs = FavoritesManager.shared.favoriteStockSymbols
            
            self.favoriteCryptos = fetchedCryptos.filter { cryptoFavs.contains($0.symbol) }
            self.favoriteStocks = fetchedStocks.filter { stockFavs.contains($0.symbol) }
            
            // Cache logos for widgets
            WidgetLogoManager.shared.cacheLogos(for: self.favoriteCryptos.map { $0.symbol })
            
            Task {
                await webSocketClient.connect()
                scheduleSubscribe()
            }
            
        } catch {
            print("FavoritesViewModel Error: \\(error)")
        }
        
        isLoading = false
        syncToWidget()
    }
    
    private func listenToNetworkState() {
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)
    }
    
    private func scheduleSubscribe() {
        subscribeTask?.cancel()
        subscribeTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let symbols = self.favoriteCryptos.map { $0.symbol }
            await self.webSocketClient.subscribe(symbols: symbols)
        }
    }
    
    private func updateCryptoPrice(_ tick: WebSocketPriceTick) {
        let symbol = tick.symbol.uppercased()
        if let idx = favoriteCryptos.firstIndex(where: { $0.symbol.uppercased() == symbol }) {
            let old = favoriteCryptos[idx]
            let updated = Crypto(
                symbol: old.symbol,
                lastPrice: tick.price,
                priceChangePercent: tick.priceChangePercent ?? old.priceChangePercent,
                highPrice: old.highPrice,
                lowPrice: old.lowPrice,
                volume: old.volume
            )
            favoriteCryptos[idx] = updated
            syncToWidget()
        }
    }
    
    public func removeFavoriteStock(_ stock: Stock) {
        FavoritesManager.shared.toggleStockFavorite(stock.symbol)
    }
    
    public func removeFavoriteCrypto(_ crypto: Crypto) {
        FavoritesManager.shared.toggleCryptoFavorite(crypto.symbol)
    }

    // MARK: - Widget Sync
    private func syncToWidget() {
        let authManager = AuthManager.shared
        guard authManager.isAuthenticated else { return }
        
        WidgetDataBridge.shared.syncFavorites(
            cryptoSymbols: favoriteCryptos.map { $0.symbol },
            stockSymbols: favoriteStocks.map { $0.symbol },
            priceResolver: { symbol, kind in
                if kind == "crypto" {
                    if let crypto = self.favoriteCryptos.first(where: { $0.symbol == symbol }) {
                        let val = Double(crypto.lastPrice) ?? 0
                        let fmtPrice = self.formatPrice(crypto.lastPrice)
                        let pct = Double(crypto.priceChangePercent) ?? 0
                        let fmtPct = String(format: "%@%.2f%%", pct >= 0 ? "+" : "", pct)
                        return (price: fmtPrice, change: fmtPct, isPositive: pct >= 0, usdPrice: val)
                    }
                } else {
                    if let stock = self.favoriteStocks.first(where: { $0.symbol == symbol }) {
                        let price = "\u{20BA}" + stock.lastPrice
                        let val = Double(stock.lastPrice) ?? 0
                        let usdVal = val / 45.0 // Approximate 2026 USD/TRY Rate
                        return (price: price, change: stock.changePercent, isPositive: stock.changePercent.hasPrefix("+"), usdPrice: usdVal)
                    }
                }
                return (price: "—", change: "—", isPositive: true, usdPrice: 0)
            }
        )
    }
    
    public func formatPrice(_ amountStr: String) -> String {
        guard let value = Double(amountStr) else { return "$0.00" }
        if value >= 1 {
            return String(format: "$%.2f", value)
        } else if value >= 0.0001 {
            return String(format: "$%.4f", value)
        } else {
            return "$ " + String(format: "%.8f", value)
        }
    }
}
