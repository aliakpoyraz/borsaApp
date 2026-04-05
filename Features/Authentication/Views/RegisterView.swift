import SwiftUI

public struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingSuccess = false
    @ObservedObject private var authManager = AuthManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Arka Plan
                premiumBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 40)
                        
                        headerView
                        
                        VStack(spacing: 24) {
                            if showingSuccess {
                                successStateView
                            } else {
                                inputFormSection
                                
                                actionButtonsSection
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
                        
                        loginToggle
                        
                        Spacer().frame(height: 40)
                    }
                    .frame(minHeight: 600)
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: authManager.isAuthenticated) { _, authenticated in
                if authenticated {
                    dismiss()
                }
            }
            .alert(isPresented: $viewModel.showError) {
                SwiftUI.Alert(
                    title: Text("Hata"),
                    message: Text(viewModel.errorMessage ?? "Bilinmeyen bir hata oluştu."),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
    }
    
    //Bileşenler
    private var premiumBackground: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            LinearGradient(colors: [
                .green.opacity(0.15),
                .blue.opacity(0.1),
                Color(.systemBackground)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -150, y: -250)
            
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 150, y: 150)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.green.gradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text("Hesap Oluştur")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Ücretsiz kayıt olun ve portföyünüzü yönetin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var successStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: showingSuccess)
            
            Text("Harika!")
                .font(.title2.weight(.bold))
            
            Text("Hesabınız başarıyla oluşturuldu.\nGiriş yapılıyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ProgressView()
                .padding(.top, 8)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private var inputFormSection: some View {
        VStack(spacing: 4) {
            // E-posta alanı
            customTextField(title: "E-posta", text: $viewModel.email, icon: "envelope")
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .onChange(of: viewModel.email) { _, _ in viewModel.validateEmail() }

            if let emailErr = viewModel.emailError {
                fieldError(emailErr)
            }

            Spacer().frame(height: 8)

            // Şifre alanı
            customSecureField(title: "Şifre", text: $viewModel.password, icon: "lock")
                .onChange(of: viewModel.password) { _, _ in viewModel.validatePassword() }

            if let passErr = viewModel.passwordError {
                fieldError(passErr)
            }

            Spacer().frame(height: 8)

            // Şifre Onayla alanı
            customSecureField(title: "Şifreyi Onayla", text: $viewModel.confirmPassword, icon: "lock.shield")
                .onChange(of: viewModel.confirmPassword) { _, _ in viewModel.validateConfirmPassword() }

            if let confirmPassErr = viewModel.confirmPasswordError {
                fieldError(confirmPassErr)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 54)
            } else {
                Button(action: {
                    Task {
                        let success = await viewModel.signUp()
                        if success {
                            withAnimation(.spring()) {
                                showingSuccess = true
                            }
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            dismiss()
                        }
                    }
                }) {
                    Text("Kayıt Ol")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.green.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                HStack {
                    Rectangle().fill(.secondary.opacity(0.2)).frame(height: 1)
                    Text("veya").font(.caption).foregroundColor(.secondary).padding(.horizontal, 8)
                    Rectangle().fill(.secondary.opacity(0.2)).frame(height: 1)
                }
                
                Button(action: {
                    viewModel.signInWithGoogle()
                }) {
                    HStack(spacing: 10) {
                        GoogleLogoView()
                            .frame(width: 22, height: 22)
                        
                        Text("Google ile Kayıt Ol")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(UIColor.separator.withAlphaComponent(0.4)), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                }
            }
        }
    }
    
    private var loginToggle: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 4) {
                Text("Zaten bir hesabınız var mı?")
                    .foregroundColor(.secondary)
                Text("Giriş Yapın")
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .font(.footnote)
        }
    }
    
    private func fieldError(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
            Text(message)
                .font(.caption)
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func customTextField(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            TextField(title, text: text)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func customSecureField(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            SecureField(title, text: text)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .preferredColorScheme(.dark)
    }
}
