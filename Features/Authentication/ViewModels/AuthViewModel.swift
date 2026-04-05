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

    // Inline alan hataları (her alanın altında gösterilir)
    @Published public var emailError: String?
    @Published public var passwordError: String?
    @Published public var confirmPasswordError: String?

    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false

    public init() {}

    // MARK: - Doğrulama yardımcıları

    public var isEmailValid: Bool {
        let regex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    public var isPasswordValid: Bool { password.count >= 6 }
    public var doPasswordsMatch: Bool { password == confirmPassword }

    public func validateEmail() {
        guard !email.isEmpty else { emailError = nil; return }
        emailError = isEmailValid ? nil : "Geçerli bir e-posta girin (örn. ad@mail.com)"
    }

    public func validatePassword() {
        guard !password.isEmpty else { passwordError = nil; return }
        passwordError = isPasswordValid ? nil : "Şifre en az 6 karakter olmalıdır"
    }

    public func validateConfirmPassword() {
        guard !confirmPassword.isEmpty else { confirmPasswordError = nil; return }
        confirmPasswordError = doPasswordsMatch ? nil : "Şifreler eşleşmiyor"
    }

    // MARK: - Giriş

    public func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            showErrorAlert("Lütfen e-posta ve şifrenizi girin.")
            return
        }
        guard isEmailValid else {
            emailError = "Geçerli bir e-posta girin (örn. ad@mail.com)"
            return
        }
        guard isPasswordValid else {
            passwordError = "Şifre en az 6 karakter olmalıdır"
            return
        }

        isLoading = true
        do {
            try await SupabaseAuthService.shared.signIn(email: email, password: password)
        } catch {
            showErrorAlert("E-posta veya şifre hatalı. Lütfen tekrar deneyin.")
        }
        isLoading = false
    }

    // MARK: - Kayıt

    public func signUp() async -> Bool {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            showErrorAlert("Lütfen tüm alanları doldurun.")
            return false
        }
        guard isEmailValid else {
            emailError = "Geçerli bir e-posta girin (örn. ad@mail.com)"
            return false
        }
        guard isPasswordValid else {
            passwordError = "Şifre en az 6 karakter olmalıdır"
            return false
        }
        guard doPasswordsMatch else {
            confirmPasswordError = "Şifreler eşleşmiyor"
            return false
        }

        isLoading = true
        do {
            try await SupabaseAuthService.shared.signUp(email: email, password: password)
            isLoading = false
            return true
        } catch {
            showErrorAlert("Kayıt başarısız. Bu e-posta zaten kullanımda olabilir.")
            isLoading = false
            return false
        }
    }

    private func showErrorAlert(_ msg: String) {
        self.errorMessage = msg
        self.showError = true
    }

    // MARK: - Google ile Giriş Yap (Sign-In)

    public func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            showErrorAlert("Bilinmeyen bir UI hatası oluştu.")
            return
        }

        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] signInResult, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    self.isLoading = false
                    if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
                    self.showErrorAlert(error.turkishDescription)
                    return
                }

                guard let user = signInResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    self.showErrorAlert("Google'dan kimlik doğrulayıcı (token) alınamadı.")
                    return
                }

                do {
                    try await SupabaseAuthService.shared.signInWithGoogleIdToken(idToken)
                    self.isLoading = false
                } catch {
                    self.isLoading = false
                    self.showErrorAlert(error.turkishDescription)
                }
            }
        }
    }
}
