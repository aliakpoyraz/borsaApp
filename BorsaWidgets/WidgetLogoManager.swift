import Foundation
import UIKit
import WidgetKit

public final class WidgetLogoManager {
    public static let shared = WidgetLogoManager()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }
    
    /// Downloads and caches logos for a list of crypto symbols.
    public func cacheLogos(for symbols: [String]) {
        let container = WidgetSharedData.sharedContainerURL
        if container == nil {
            print("⚠️ HATA: App Group ID (\(WidgetSharedData.appGroupID)) Xcode'da henüz tanımlanmamış!")
        }
        
        Task {
            for symbol in symbols {
                await cacheLogo(for: symbol)
            }
            // All logos in batch cached, notify widgets
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func cacheLogo(for symbol: String) async {
        guard let targetURL = WidgetSharedData.logoURL(for: symbol) else { return }
        
        // Skip if already cached
        if FileManager.default.fileExists(atPath: targetURL.path) {
            return
        }
        
        // Use clean symbol for URL
        let cleanSymbol = targetURL.deletingPathExtension().lastPathComponent
        let sourceURLString = "https://assets.coincap.io/assets/icons/\(cleanSymbol)@2x.png"
        guard let sourceURL = URL(string: sourceURLString) else { return }
        
        do {
            let (data, response) = try await session.data(from: sourceURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }
            
            // Validate it's an image
            guard UIImage(data: data) != nil else { return }
            
            // Save to shared container
            try data.write(to: targetURL)
            print("✅ Logo Önbelleğe Alındı: \(symbol)")
        } catch {
            print("❌ Logo İndirme Hatası (\(symbol)): \(error)")
        }
    }
}
