import Foundation
import Combine
import SwiftUI

@MainActor
public final class PortfolioViewModel: ObservableObject {
    @Published public private(set) var totalBalance: Decimal = 0 // Varlıkların Toplam Değerini Temsil Eder (Fiat/Nakit Değil)
    @Published public private(set) var assetsWithPnL: [PortfolioAssetPnL] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var usdToTryRate: Decimal = 32.5
    
    // Bağımlılıklar (Dependencies)
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
        let upperSymbol = symbol.uppercased()
        var found = false
        
        for i in 0..<assetsWithPnL.count {
            let assetSymbol = assetsWithPnL[i].symbol.uppercased()
            // BTC vs BTCUSDT eşleşmesini kontrol et
            if assetSymbol == upperSymbol || (assetsWithPnL[i].kind == .crypto && (assetSymbol + "USDT" == upperSymbol || upperSymbol + "USDT" == assetSymbol)) {
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
            
            // Widget'lar için logoları önbelleğe al (Sadece kriptolar)
            let cryptoSymbols = fetchedAssets.filter { $0.kind == .crypto }.map { $0.symbol }
            WidgetLogoManager.shared.cacheLogos(for: cryptoSymbols)
            
            // Toplam portföy değerini TL cinsinden dinamik olarak hesapla
            self.totalBalance = fetchedAssets.reduce(Decimal(0)) { $0 + $1.totalValueTL(rate: rate) }
            
        } catch {
            // Ağ hatası durumunda popup göstermek yerine banner'a güveniyoruz
            print("PortfolioViewModel Hatası: \(error)")
        }
        
        isLoading = false
        syncToWidget()
    }
    
    public func addAsset(kind: PortfolioAssetKind, symbol: String, quantityStr: String) async -> Bool {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Sadece virgülleri noktaya çevirerek global (.) ondalık formatına uyumlu hale getiriyoruz. Noktaları silmiyoruz.
        let cleanedStr = quantityStr.replacingOccurrences(of: ",", with: ".")
        guard let quantity = Decimal(string: cleanedStr, locale: Locale(identifier: "en_US_POSIX")) else {
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
            self.errorMessage = error.turkishDescription
            return false
        }
    }
    
    public func removeAsset(asset: PortfolioAssetPnL) async {
        do {
            // Tüm miktarı sil
            try await portfolioService.sell(kind: asset.kind, symbol: asset.symbol, quantity: asset.quantity)
            await loadData()
        } catch {
            self.errorMessage = error.turkishDescription
        }
    }

    public func updateAssetQuantity(asset: PortfolioAssetPnL, newQuantityStr: String) async -> Bool {
        // Sadece virgülleri noktaya çevirerek global (.) ondalık formatına uyumlu hale getiriyoruz. Noktaları silmiyoruz.
        let cleanedStr = newQuantityStr.replacingOccurrences(of: ",", with: ".")
        guard let quantity = Decimal(string: cleanedStr, locale: Locale(identifier: "en_US_POSIX")) else {
            self.errorMessage = "Geçersiz miktar."
            return false
        }
        
        do {
            try await portfolioService.updateQuantity(kind: asset.kind, symbol: asset.symbol, newQuantity: quantity)
            await loadData()
            return true
        } catch {
            self.errorMessage = error.turkishDescription
            return false
        }
    }
    
    // MARK: - Widget Senkronizasyonu (Widget Sync)
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

    // Formatlama Yardımcıları (Format helpers)
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
