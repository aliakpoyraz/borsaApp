import Foundation
import WidgetKit

/// App Group üzerinden BorsaWidgets uzantısı ile tüm veri alışverişini yönetir.
public final class WidgetDataBridge {
    public static let shared = WidgetDataBridge()
    
    private let appGroupID = "group.com.borsaapp.shared"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - Uygulama Durumu (Okuma)
    
    public var isLoggedIn: Bool { defaults?.bool(forKey: WidgetDefaultsKey.isLoggedIn) ?? false }
    public var isBalanceHidden: Bool { defaults?.bool(forKey: WidgetDefaultsKey.isBalanceHidden) ?? false }
    public var userName: String { defaults?.string(forKey: WidgetDefaultsKey.userName) ?? "" }
    
    public var favoriteCryptos: [WidgetFavoriteItem] {
        guard let data = defaults?.data(forKey: WidgetDefaultsKey.favoriteCryptos) else { return [] }
        return (try? JSONDecoder().decode([WidgetFavoriteItem].self, from: data)) ?? []
    }
    
    public var favoriteStocks: [WidgetFavoriteItem] {
        guard let data = defaults?.data(forKey: WidgetDefaultsKey.favoriteStocks) else { return [] }
        return (try? JSONDecoder().decode([WidgetFavoriteItem].self, from: data)) ?? []
    }
    
    public var portfolioAssets: [WidgetPortfolioItem] {
        guard let data = defaults?.data(forKey: WidgetDefaultsKey.portfolioAssets) else { return [] }
        return (try? JSONDecoder().decode([WidgetPortfolioItem].self, from: data)) ?? []
    }
    
    public var totalPortfolioValue: String {
        defaults?.string(forKey: WidgetDefaultsKey.totalPortfolioValue) ?? "₺0"
    }
    
    public var allFavorites: [WidgetFavoriteItem] {
        favoriteCryptos + favoriteStocks
    }
    
    public var topFavorites: [WidgetFavoriteItem] {
        guard let data = defaults?.data(forKey: WidgetDefaultsKey.topFavorites) else { return [] }
        return (try? JSONDecoder().decode([WidgetFavoriteItem].self, from: data)) ?? []
    }

    // MARK: - Senkronizasyon (Yazma)

    public func syncAuthState(isLoggedIn: Bool, userEmail: String) {
        defaults?.set(isLoggedIn, forKey: WidgetDefaultsKey.isLoggedIn)
        defaults?.set(userEmail, forKey: WidgetDefaultsKey.userName)
        reloadWidgets()
    }
    
    public func syncBalanceVisibility(isHidden: Bool) {
        defaults?.set(isHidden, forKey: WidgetDefaultsKey.isBalanceHidden)
        reloadWidgets()
    }

    public func syncFavorites(
        cryptoSymbols: [String],
        stockSymbols: [String],
        priceResolver: (String, String) -> (price: String, change: String, isPositive: Bool, usdPrice: Double)
    ) {
        let cryptos = cryptoSymbols.map { sym in
            let resolved = priceResolver(sym, "crypto")
            return (
                item: WidgetFavoriteItem(symbol: sym, kind: "crypto", price: resolved.price, change: resolved.change, isPositive: resolved.isPositive),
                usdPrice: resolved.usdPrice
            )
        }
        let stocks = stockSymbols.map { sym in
            let resolved = priceResolver(sym, "stock")
            return (
                item: WidgetFavoriteItem(symbol: sym, kind: "stock", price: resolved.price, change: resolved.change, isPositive: resolved.isPositive),
                usdPrice: resolved.usdPrice
            )
        }

        // En değerli ilk 3 varlığı hesapla (USD bazlı sıralama)
        let allItems = (cryptos + stocks).sorted { (a, b) -> Bool in
            return a.usdPrice > b.usdPrice
        }
        let top3 = allItems.prefix(3).map { $0.item }

        let encoder = JSONEncoder()
        if let c = try? encoder.encode(cryptos.map { $0.item }) { defaults?.set(c, forKey: WidgetDefaultsKey.favoriteCryptos) }
        if let s = try? encoder.encode(stocks.map { $0.item }) { defaults?.set(s, forKey: WidgetDefaultsKey.favoriteStocks) }
        if let t = try? encoder.encode(top3) { defaults?.set(t, forKey: WidgetDefaultsKey.topFavorites) }
        
        reloadWidgets()
    }

    public func syncPortfolio(
        assets: [(symbol: String, kind: String, quantity: Decimal, totalValue: Decimal)],
        totalPortfolioValue: Decimal
    ) {
        // En değerli olanları göstermek için toplam değere göre azalan sırada sırala
        let sortedSorted = assets.sorted { $0.totalValue > $1.totalValue }
        
        // İstenildiği üzere widget için en üstteki 2 tanesini al
        let topAssets = sortedSorted.prefix(2).map { a -> WidgetPortfolioItem in
            let qty = "\(a.quantity)"
            let val = formatTL(a.totalValue)
            return WidgetPortfolioItem(symbol: a.symbol, kind: a.kind, quantity: qty, totalValue: val)
        }

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(topAssets) {
            defaults?.set(data, forKey: WidgetDefaultsKey.portfolioAssets)
        }
        
        // Genel toplamı ayrı olarak depola
        defaults?.set(formatTL(totalPortfolioValue), forKey: WidgetDefaultsKey.totalPortfolioValue)
        
        reloadWidgets()
    }
    
    public func refreshNetworkData() async {
        // Uygulama başlatılmadan widget'ları güncel tutmak için gerçek zamanlı kripto fiyatlarını çek
        let cryptos = self.favoriteCryptos
        var activeCryptoSymbols = Set(cryptos.map { $0.symbol })
        
        let pAssets = self.portfolioAssets
        pAssets.filter { $0.kind == "crypto" }.forEach { activeCryptoSymbols.insert($0.symbol) }
        
        guard !activeCryptoSymbols.isEmpty else { return }
        
        // Binance API'den verileri çek
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            
            var priceMap: [String: (price: Double, change: Double)] = [:]
            for obj in json {
                if let sym = obj["symbol"] as? String, activeCryptoSymbols.contains(sym),
                   let priceStr = obj["lastPrice"] as? String, let price = Double(priceStr),
                   let changeStr = obj["priceChangePercent"] as? String, let change = Double(changeStr) {
                    priceMap[sym] = (price, change)
                }
            }
            
            // Favorileri güncelle
            var updatedCryptos = cryptos
            for i in 0..<updatedCryptos.count {
                let sym = updatedCryptos[i].symbol
                if let info = priceMap[sym] {
                    let fmtPrice = info.price >= 1 ? String(format: "$%.2f", info.price) : String(format: "$%.4f", info.price)
                    let fmtChange = String(format: "%@%.2f%%", info.change >= 0 ? "+" : "", info.change)
                    updatedCryptos[i] = WidgetFavoriteItem(symbol: sym, kind: "crypto", price: fmtPrice, change: fmtChange, isPositive: info.change >= 0)
                }
            }
            let encoder = JSONEncoder()
            if let c = try? encoder.encode(updatedCryptos) { defaults?.set(c, forKey: WidgetDefaultsKey.favoriteCryptos) }
            
            // Portföy varlıklarını güncelle
            let updatedPortfolio = pAssets
            
            for i in 0..<updatedPortfolio.count {
                let p = updatedPortfolio[i]
                if let _ = priceMap[p.symbol], let _ = Double(p.quantity.replacingOccurrences(of: ",", with: ".")) {
                }
            }
            // Not: Basitlik adına burada TL cinsinden toplam değeri yeniden hesaplamıyoruz, ana uygulamaya güveniyoruz.
        } catch {
            // Hata durumunda yerel önbelleği kullanıyoruz
        }
    }

    // MARK: - Yardımcı Metotlar (Helpers)

    private func formatTL(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₺"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: value as NSDecimalNumber) ?? "₺0"
    }

    private func reloadWidgets() {
        // Verileri hemen kalıcı hale getirmeye zorla (Bazı iOS sürümlerinde App Group'lar için yararlıdır)
        defaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
