import Foundation
import Combine
import SwiftUI

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var cryptos: [Crypto] = []
    @Published public private(set) var stocks: [Stock] = []
    @Published public private(set) var portfolioBalance: Decimal = 0
    @Published public private(set) var portfolioStockCount: Int = 0
    @Published public private(set) var portfolioCryptoCount: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    // Canlı Takip Verileri
    private var assets: [PortfolioAssetPnL] = []
    private var usdToTryRate: Decimal = 32.3
    
    // Bağımlılıklar (Dependencies)
    private let cryptoService: CryptoServicing
    private let bistService: BistServicing
    private let portfolioService: PortfolioServicing
    private let webSocketClient: WebSocketClienting
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        cryptoService: CryptoServicing? = nil,
        bistService: BistServicing? = nil,
        portfolioService: PortfolioServicing? = nil,
        webSocketClient: WebSocketClienting? = nil
    ) {
        self.cryptoService = cryptoService ?? CryptoService.shared
        self.bistService = bistService ?? BistService.shared
        self.portfolioService = portfolioService ?? PortfolioService.shared
        self.webSocketClient = webSocketClient ?? WebSocketClient.shared
        
        setupLivePrices()
        subscribeToPortfolioUpdates()
    }
    

    private func subscribeToPortfolioUpdates() {
        portfolioService.priceUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handlePortfolioPriceUpdate(symbol: update.symbol, price: update.price, percent: update.percent)
            }
            .store(in: &cancellables)
    }
    
    public func loadData() async {
        isLoading = true
        errorMessage = nil

        // Kripto ve hisseleri paralel olarak yükle
        async let cryptosTask = cryptoService.fetchAll24hTickers(cachePolicy: .useCacheIfAvailable)
        async let stocksTask = bistService.fetchStocks(forceRefresh: false)
        async let portfolioTask = portfolioService.getAssetsWithValue()

        let (fetchedCryptos, fetchedStocks, assets) = await (cryptosTask, stocksTask, (try? portfolioTask) ?? [])

        // Gerçek varlıklardan bakiye ve sayıları hesapla
        let rate = await CurrencyService.shared.fetchUSDTTRYRate()
        self.usdToTryRate = rate
        self.assets = assets
        recalculatePortfolioBalance()
        
        self.portfolioStockCount = assets.filter { $0.kind == .stock }.count
        self.portfolioCryptoCount = assets.filter { $0.kind == .crypto }.count

        let sortedCryptos = CryptoService.sortCryptos(fetchedCryptos)
        self.cryptos = Array(sortedCryptos.prefix(10))
        self.stocks = fetchedStocks
        isLoading = false
        
        Task {
            await webSocketClient.connect()
            await webSocketClient.subscribe(symbols: self.cryptos.map { $0.symbol })
        }
    }
    
    private func setupLivePrices() {
        webSocketClient.pricePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tick in
                self?.updateCryptoPrice(tick)
            }
            .store(in: &cancellables)
    }
    
    private func updateCryptoPrice(_ tick: WebSocketPriceTick) {
        let symbol = tick.symbol.uppercased()
        if let idx = cryptos.firstIndex(where: { $0.symbol.uppercased() == symbol }) {
            let old = cryptos[idx]
            cryptos[idx] = Crypto(
                symbol: old.symbol,
                lastPrice: tick.price,
                priceChangePercent: tick.priceChangePercent ?? old.priceChangePercent,
                highPrice: old.highPrice,
                lowPrice: old.lowPrice,
                volume: old.volume
            )
        }
    }
    
    private func handlePortfolioPriceUpdate(symbol: String, price: Decimal, percent: Decimal?) {
        let upperSymbol = symbol.uppercased()
        var found = false
        
        for i in 0..<assets.count {
            let assetSymbol = assets[i].symbol.uppercased()
            // BTC vs BTCUSDT eşleşmesini kontrol et (Aynı mantık)
            if assetSymbol == upperSymbol || (assets[i].kind == .crypto && (assetSymbol + "USDT" == upperSymbol || upperSymbol + "USDT" == assetSymbol)) {
                let old = assets[i]
                assets[i] = PortfolioAssetPnL(
                    symbol: old.symbol,
                    kind: old.kind,
                    quantity: old.quantity,
                    currentPrice: price,
                    currentChangePercent: percent ?? old.currentChangePercent
                )
                found = true
            }
        }
        
        if found {
            recalculatePortfolioBalance()
        }
    }
    
    private func recalculatePortfolioBalance() {
        self.portfolioBalance = assets.reduce(Decimal(0)) { $0 + $1.totalValueTL(rate: usdToTryRate) }
    }
    
    // Formatlama Yardımcıları (Format helpers)
    public func formatPrice(amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₺"
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "₺0.00"
    }
    
    public func formatCryptoPrice(_ priceString: String) -> String {
        guard let value = Double(priceString) else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        if value < 1 { formatter.maximumFractionDigits = 4 }
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    public func formatChange(_ changeString: String) -> String {
        guard let value = Double(changeString) else { return "0.00%" }
        let prefix = value > 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, value)
    }
}
