import SwiftUI
import Foundation
import Combine
import GoogleSignIn
import UIKit

@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var confirmPassword = ""
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false

    public init() {}

    public func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            showError(msg: "Lütfen e-posta ve şifrenizi girin.")
            return
        }
        
        isLoading = true
        do {
            try await SupabaseAuthService.shared.signIn(email: email, password: password)
        } catch {
            showError(msg: error.localizedDescription)
        }
        isLoading = false
    }
    
    public func signUp() async -> Bool {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            showError(msg: "Lütfen tüm alanları doldurun.")
            return false
        }
        guard password == confirmPassword else {
            showError(msg: "Şifreler eşleşmiyor.")
            return false
        }
        
        isLoading = true
        do {
            try await SupabaseAuthService.shared.signUp(email: email, password: password)
            isLoading = false
            return true
        } catch {
            showError(msg: error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    private func showError(msg: String) {
        self.errorMessage = msg
        self.showError = true
    }
    
    // MARK: - Google Sign-In
    public func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            showError(msg: "Bilinmeyen bir UI hatası oluştu.")
            return
        }
        
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] signInResult, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    // İptal edildiyse hata gösterme
                    if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
                    self.showError(msg: error.localizedDescription)
                    return
                }
                
                guard let user = signInResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    self.showError(msg: "Google'dan kimlik doğrulayıcı (token) alınamadı.")
                    return
                }
                
                // Supabase Auth işlemi başlatılıyor.
                do {
                    try await SupabaseAuthService.shared.signInWithGoogleIdToken(idToken)
                    self.isLoading = false
                } catch {
                    self.isLoading = false
                    self.showError(msg: error.localizedDescription)
                }
            }
        }
    }
}
