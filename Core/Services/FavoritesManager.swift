import Foundation
import Combine
import SwiftUI

public struct FavoriteResponse: Codable {
    public let id: String
    public let symbol: String
    public let kind: String
}

@MainActor
public final class FavoritesManager: ObservableObject {
    public static let shared = FavoritesManager()
    
    @Published public private(set) var favoriteCryptoSymbols: [String] = []
    @Published public private(set) var favoriteStockSymbols: [String] = []
    
    private init() {
        // Oturum açan kullanıcının favorilerini çekmek için dinleyici koyalabiliriz
        // Ancak bu asenkron olduğundan dışarıdan çağrılması daha sağılıklı. (Örn: MainTabView onAppear)
    }
    
    public func loadFavorites() async {
        guard let token = await getAccessToken(), !token.isEmpty else { return }
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/favorites?select=*") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let favorites = try JSONDecoder().decode([FavoriteResponse].self, from: data)
                
                self.favoriteCryptoSymbols = favorites.filter { $0.kind == "crypto" }.map { $0.symbol }.sorted()
                self.favoriteStockSymbols = favorites.filter { $0.kind == "stock" }.map { $0.symbol }.sorted()
            }
        } catch {
            print("Favoriler yüklenemedi: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Crypto
    public func isCryptoFavorite(_ symbol: String) -> Bool {
        favoriteCryptoSymbols.contains(symbol)
    }
    
    public func toggleCryptoFavorite(_ symbol: String) {
        if isCryptoFavorite(symbol) {
            favoriteCryptoSymbols.removeAll { $0 == symbol }
            Task { await syncDelete(symbol: symbol, kind: "crypto") }
        } else {
            favoriteCryptoSymbols.append(symbol)
            Task { await syncAdd(symbol: symbol, kind: "crypto") }
        }
    }
    
    // MARK: - Stocks (BIST)
    public func isStockFavorite(_ symbol: String) -> Bool {
        favoriteStockSymbols.contains(symbol)
    }
    
    public func toggleStockFavorite(_ symbol: String) {
        if isStockFavorite(symbol) {
            favoriteStockSymbols.removeAll { $0 == symbol }
            Task { await syncDelete(symbol: symbol, kind: "stock") }
        } else {
            favoriteStockSymbols.append(symbol)
            Task { await syncAdd(symbol: symbol, kind: "stock") }
        }
    }
    
    // MARK: - API Sync Helpers
    
    private func getAccessToken() async -> String? {
        // DispatchQueue arkasından çalışmaması veya MainActor'dan güvenli okunabilmesi için
        return UserDefaults.standard.string(forKey: "supabaseAccessToken")
    }
    
    private func syncAdd(symbol: String, kind: String) async {
        guard let token = await getAccessToken(), !token.isEmpty else { return }
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/favorites") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        let body: [String: String] = ["symbol": symbol, "kind": kind]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
                print("Ekleme hatası: Statü \(httpRes.statusCode)")
            }
        } catch {
            print("Ekleme hatası: \(error.localizedDescription)")
        }
    }
    
    private func syncDelete(symbol: String, kind: String) async {
        guard let token = await getAccessToken(), !token.isEmpty else { return }
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/rest/v1/favorites?symbol=eq.\(symbol)&kind=eq.\(kind)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
                print("Silme hatası: Statü \(httpRes.statusCode)")
            }
        } catch {
            print("Silme hatası: \(error.localizedDescription)")
        }
    }
    
    public func clearLocalCache() {
        self.favoriteStockSymbols.removeAll()
        self.favoriteCryptoSymbols.removeAll()
    }
}
