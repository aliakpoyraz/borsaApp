import Foundation
import SwiftUI
import Combine

public class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    @AppStorage("supabaseAccessToken") public var accessToken: String = ""
    @AppStorage("supabaseRefreshToken") public var refreshToken: String = ""
    @AppStorage("supabaseUserEmail") public var userEmail: String = ""
    
    @Published public var isAuthenticated: Bool = false
    
    private init() {
        self.isAuthenticated = !accessToken.isEmpty
    }
    
    public func logIn(token: String, refresh: String, email: String) {
        self.accessToken = token
        self.refreshToken = refresh
        self.userEmail = email
        self.isAuthenticated = true
        WidgetDataBridge.shared.syncAuthState(isLoggedIn: true, userEmail: email)
    }

    /// Refreshes the access token using the stored refresh token.
    /// Returns the new access token, or nil if refresh fails (forces logout).
    @discardableResult
    public func refreshTokenIfNeeded() async -> String? {
        guard !refreshToken.isEmpty else {
            logOut()
            return nil
        }

        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/auth/v1/token?grant_type=refresh_token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newToken = json["access_token"] as? String {
                let newRefresh = json["refresh_token"] as? String ?? self.refreshToken
                let email = self.userEmail
                await MainActor.run {
                    self.logIn(token: newToken, refresh: newRefresh, email: email)
                }
                return newToken
            } else {
                // Refresh failed — log out
                await MainActor.run { self.logOut() }
                return nil
            }
        } catch {
            await MainActor.run { self.logOut() }
            return nil
        }
    }

    public func logOut() {
        self.accessToken = ""
        self.refreshToken = ""
        self.userEmail = ""
        self.isAuthenticated = false
        WidgetDataBridge.shared.syncAuthState(isLoggedIn: false, userEmail: "")
    }
}

public enum AuthError: Error, LocalizedError {
    case invalidURL
    case serverError(String)
    case credentialsError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz İstek Adresi."
        case .serverError(let msg): return msg
        case .credentialsError: return "E-posta veya şifre hatalı."
        }
    }
}

public struct SupabaseAuthResponse: Codable {
    public let accessToken: String
    public let refreshToken: String?
    public let user: SupabaseUser?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

public struct SupabaseUser: Codable {
    public let email: String?
}

public class SupabaseAuthService {
    
    public static let shared = SupabaseAuthService()
    private init() {}
    
    private let session = URLSession.shared
    
    private func translateError(_ error: String) -> String {
        let msg = error.lowercased()
        if msg.contains("invalid login") || msg.contains("invalid credentials") {
            return "E-posta veya şifre hatalı."
        }
        if msg.contains("already registered") || msg.contains("already exists") {
            return "Bu e-posta adresi zaten kullanımda."
        }
        if msg.contains("password should be at least") || msg.contains("password must") {
            return "Şifre çok kısa. Lütfen en az 6 karakter girin."
        }
        if msg.contains("email not confirmed") {
            return "E-posta onaylanmadı. Lütfen e-postanızı kontrol edin veya Supabase Dashboard üzerinden 'Confirm Email' ayarını kapatın."
        }
        if msg.contains("rate limit") || msg.contains("too many requests") {
            return "Çok fazla istek yapıldı. Lütfen biraz bekleyip tekrar deneyin."
        }
        if msg.contains("valid email") {
            return "Lütfen geçerli bir e-posta adresi girin."
        }
        return error
    }
    
    public func signUp(email: String, password: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/auth/v1/signup") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = (errDict["message"] as? String) ?? (errDict["error_description"] as? String) ?? (errDict["msg"] as? String) {
                throw AuthError.serverError(translateError(msg))
            }
            throw AuthError.serverError("Kayıt işlemi başarısız. Lütfen tekrar deneyin.")
        }
        
        // Eğer kayıt başarılıysa direkt giriş yapıyormuş gibi davranabiliriz.
        try await signIn(email: email, password: password)
    }
    
    public func signIn(email: String, password: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/auth/v1/token?grant_type=password") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = (errDict["error_description"] as? String) ?? (errDict["message"] as? String) ?? (errDict["msg"] as? String) {
                throw AuthError.serverError(translateError(msg))
            }
            throw AuthError.credentialsError
        }
        
        let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        let safeEmail = authResponse.user?.email ?? email
        
        DispatchQueue.main.async {
            AuthManager.shared.logIn(token: authResponse.accessToken, refresh: authResponse.refreshToken ?? "", email: safeEmail)
        }
    }
    
    public func signInWithGoogleIdToken(_ idToken: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/auth/v1/token?grant_type=id_token") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["provider": "google", "id_token": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = (errDict["error_description"] as? String) ?? (errDict["message"] as? String) ?? (errDict["msg"] as? String) {
                throw AuthError.serverError(translateError(msg))
            }
            throw AuthError.credentialsError
        }
        
        let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        let safeEmail = authResponse.user?.email ?? "google_user"
        
        DispatchQueue.main.async {
            AuthManager.shared.logIn(token: authResponse.accessToken, refresh: authResponse.refreshToken ?? "", email: safeEmail)
        }
    }
}
