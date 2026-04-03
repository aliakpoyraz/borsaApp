import Foundation
import Combine
import SwiftUI

@MainActor
public final class PortfolioViewModel: ObservableObject {
    @Published public private(set) var totalBalance: Decimal = 0 // Represents Total Value of Assets (not fiat)
    @Published public private(set) var assetsWithPnL: [PortfolioAssetPnL] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var usdToTryRate: Decimal = 32.5
    
    // Dependencies
    private let portfolioService: PortfolioServicing
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    public init(portfolioService: PortfolioServicing? = nil) {
        self.portfolioService = portfolioService ?? PortfolioService.live()
        subscribeToPriceUpdates()
    }
    
    private func subscribeToPriceUpdates() {
        portfolioService.priceUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (update: (symbol: String, price: Decimal, percent: Decimal?)) in
                self?.handlePriceUpdate(symbol: update.symbol, price: update.price, percent: update.percent)
            }
            .store(in: &cancellables)
    }
    
    private func handlePriceUpdate(symbol: String, price: Decimal, percent: Decimal?) {
        // Find the asset(s) and update them
        var found = false
        for i in 0..<assetsWithPnL.count {
            if assetsWithPnL[i].symbol.uppercased() == symbol.uppercased() {
                let old = assetsWithPnL[i]
                assetsWithPnL[i] = PortfolioAssetPnL(
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
            // Recalculate total portfolio value dynamically in TL
            self.totalBalance = assetsWithPnL.reduce(Decimal(0)) { $0 + $1.totalValueTL(rate: usdToTryRate) }
        }
    }
    
    public func startRefreshTimer() {
        stopRefreshTimer()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                if Task.isCancelled { break }
                await loadData()
            }
        }
    }
    
    public func stopRefreshTimer() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    public func loadData() async {
        if assetsWithPnL.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let fetchedAssets = try await portfolioService.getAssetsWithValue()
            let rate = await CurrencyService.shared.fetchUSDTTRYRate()
            self.usdToTryRate = rate
            
            self.assetsWithPnL = fetchedAssets
            
            // Cache logos for widgets (only cryptos)
            let cryptoSymbols = fetchedAssets.filter { $0.kind == .crypto }.map { $0.symbol }
            WidgetLogoManager.shared.cacheLogos(for: cryptoSymbols)
            
            // Calculate total portfolio value dynamically in TL
            self.totalBalance = fetchedAssets.reduce(Decimal(0)) { $0 + $1.totalValueTL(rate: rate) }
            
        } catch {
            errorMessage = error.localizedDescription
            print("PortfolioViewModel Error: \(error)")
        }
        
        isLoading = false
        syncToWidget()
    }
    
    public func addAsset(kind: PortfolioAssetKind, symbol: String, quantityStr: String) async -> Bool {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let quantity = Decimal(string: quantityStr.replacingOccurrences(of: ",", with: ".")) else {
            self.errorMessage = "Geçersiz miktar."
            return false
        }
        
        if assetsWithPnL.contains(where: { $0.symbol.uppercased() == cleanSymbol }) {
            self.errorMessage = "Bu varlık zaten portföyünüzde bulunuyor. Lütfen varlık bilginizi düzenleyiniz."
            return false
        }
        
        do {
            try await portfolioService.buy(kind: kind, symbol: cleanSymbol, quantity: quantity)
            await loadData()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    public func removeAsset(asset: PortfolioAssetPnL) async {
        do {
            // Delete all quantity
            try await portfolioService.sell(kind: asset.kind, symbol: asset.symbol, quantity: asset.quantity)
            await loadData()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func updateAssetQuantity(asset: PortfolioAssetPnL, newQuantityStr: String) async -> Bool {
        guard let quantity = Decimal(string: newQuantityStr.replacingOccurrences(of: ",", with: ".")) else {
            self.errorMessage = "Geçersiz miktar."
            return false
        }
        
        do {
            try await portfolioService.updateQuantity(kind: asset.kind, symbol: asset.symbol, newQuantity: quantity)
            await loadData()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Widget Sync
    private func syncToWidget() {
        guard AuthManager.shared.isAuthenticated else { return }
        let isHidden = UserDefaults.standard.bool(forKey: "isBalanceHidden")
        WidgetDataBridge.shared.syncBalanceVisibility(isHidden: isHidden)
        
        let rate = usdToTryRate
        let items = assetsWithPnL.map { asset -> (symbol: String, kind: String, quantity: Decimal, totalValue: Decimal) in
            return (
                symbol: asset.symbol,
                kind: asset.kind.rawValue,
                quantity: asset.quantity,
                totalValue: asset.totalValueTL(rate: rate)
            )
        }
        WidgetDataBridge.shared.syncPortfolio(assets: items, totalPortfolioValue: self.totalBalance)
    }

    // Format helpers
    public func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₺"
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "₺0.00"
    }
    
    public func formatPercent(_ percent: Decimal) -> String {
        let value = NSDecimalNumber(decimal: percent).doubleValue
        let prefix = value > 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, value)
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
}
