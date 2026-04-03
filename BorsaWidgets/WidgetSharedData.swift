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
    public static let totalPortfolioValue = "widget_totalPortfolioValue"
    public static let isBalanceHidden = "widget_isBalanceHidden"
    public static let topFavorites = "widget_topFavorites"
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

// MARK: - Shared Constants & Helpers - Replaced by WidgetDataBridge for R/W logic.

