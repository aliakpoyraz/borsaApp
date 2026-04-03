import Foundation

// MARK: - Shared Constants & Helpers
public enum WidgetSharedData {
    public static let appGroupID = "group.com.borsaapp.shared"
    
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    public static var logoDirectoryURL: URL? {
        sharedContainerURL?.appendingPathComponent("Library/Caches/WidgetLogos", isDirectory: true)
    }
    
    public static func logoURL(for rawSymbol: String) -> URL? {
        guard let directory = logoDirectoryURL else { return nil }
        
        let symbol = rawSymbol
            .replacingOccurrences(of: "USDT", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "BUSD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "USDC", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "TRY", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        return directory.appendingPathComponent("\(symbol).png")
    }
}

// MARK: - Shared UserDefaults Keys
public enum WidgetDefaultsKey {
    public static let isLoggedIn = "widget_isLoggedIn"
    public static let userName = "widget_userName"
    public static let favoriteCryptos = "widget_favoriteCryptos"
    public static let favoriteStocks = "widget_favoriteStocks"
    public static let portfolioAssets = "widget_portfolioAssets"
    public static let isBalanceHidden = "widget_isBalanceHidden"
}

// MARK: - Shared Data Models

public struct WidgetFavoriteItem: Codable {
    public let symbol: String
    public let kind: String       // "crypto" or "stock"
    public let price: String      // formatted latest price string
    public let change: String     // formatted change % string
    public let isPositive: Bool

    public init(symbol: String, kind: String, price: String, change: String, isPositive: Bool) {
        self.symbol = symbol
        self.kind = kind
        self.price = price
        self.change = change
        self.isPositive = isPositive
    }
}

public struct WidgetPortfolioItem: Codable {
    public let symbol: String
    public let kind: String       // "crypto" or "stock"
    public let quantity: String
    public let totalValue: String // formatted in TL

    public init(symbol: String, kind: String, quantity: String, totalValue: String) {
        self.symbol = symbol
        self.kind = kind
        self.quantity = quantity
        self.totalValue = totalValue
    }
}

// MARK: - Widget Data Writer (called by main app)

public final class WidgetDataWriter {
    public static let shared = WidgetDataWriter()
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSharedData.appGroupID)
    }
    
    private init() {}
    
    public func writeLoginState(isLoggedIn: Bool, userName: String?) {
        defaults?.set(isLoggedIn, forKey: WidgetDefaultsKey.isLoggedIn)
        defaults?.set(userName ?? "", forKey: WidgetDefaultsKey.userName)
    }
    
    public func writeFavorites(cryptos: [WidgetFavoriteItem], stocks: [WidgetFavoriteItem]) {
        let encoder = JSONEncoder()
        if let cryptoData = try? encoder.encode(cryptos) {
            defaults?.set(cryptoData, forKey: WidgetDefaultsKey.favoriteCryptos)
        }
        if let stockData = try? encoder.encode(stocks) {
            defaults?.set(stockData, forKey: WidgetDefaultsKey.favoriteStocks)
        }
    }
    
    public func writePortfolio(assets: [WidgetPortfolioItem]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(assets) {
            defaults?.set(data, forKey: WidgetDefaultsKey.portfolioAssets)
        }
    }
}

// MARK: - Widget Data Reader (called by widget extension)

public final class WidgetDataReader {
    public static let shared = WidgetDataReader.sharedInstance
    private static let sharedInstance = WidgetDataReader()
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSharedData.appGroupID)
    }
    
    private init() {}
    
    public var isLoggedIn: Bool {
        defaults?.bool(forKey: WidgetDefaultsKey.isLoggedIn) ?? false
    }
    
    public var isBalanceHidden: Bool {
        defaults?.bool(forKey: WidgetDefaultsKey.isBalanceHidden) ?? false
    }
    
    public var userName: String {
        defaults?.string(forKey: WidgetDefaultsKey.userName) ?? ""
    }
    
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
    
    public var allFavorites: [WidgetFavoriteItem] {
        favoriteCryptos + favoriteStocks
    }
    
    // MARK: - Diagnostic Info
    public var statusLabel: String {
        let hasGroup = WidgetSharedData.sharedContainerURL != nil
        let groupID = String(WidgetSharedData.appGroupID.suffix(12))
        return "G:\(groupID) | C:\(hasGroup ? "OK" : "ERR")"
    }
}
