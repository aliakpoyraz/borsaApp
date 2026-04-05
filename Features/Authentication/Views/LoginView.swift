import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingRegister = false
    @ObservedObject private var authManager = AuthManager.shared
    
    private var startWithRegister: Bool
    
    public init(startWithRegister: Bool = false) {
        self.startWithRegister = startWithRegister
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Premium Arka Plan
                premiumBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 40)
                        
                        // Başlık Logo ve Başlık
                        headerView
                        
                        // Cam Görünümlü Kart
                        VStack(spacing: 24) {
                            inputFieldSection
                            
                            actionButtonsSection
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
                        
                        registrationToggle
                        
                        Spacer().frame(height: 40)
                    }
                    .frame(minHeight: 600)
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
            .onAppear {
                if startWithRegister {
                    showingRegister = true
                }
            }
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
    
    // MARK: - Arka Plan Bileşenleri
    private var premiumBackground: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            LinearGradient(colors: [
                .blue.opacity(0.15),
                .purple.opacity(0.1),
                Color(.systemBackground)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            // "Mesh" efekti için hafif bulanık daireler
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -150, y: -250)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 150, y: 150)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text("Hoş Geldiniz")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Giriş yaparak portföyünüzü takip etmeye devam edin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var inputFieldSection: some View {
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
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 54)
            } else {
                // Ana Giriş Butonu
                Button(action: {
                    Task {
                        await viewModel.signIn()
                        if AuthManager.shared.isAuthenticated {
                            dismiss()
                        }
                    }
                }) {
                    Text("Giriş Yap")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                HStack {
                    Rectangle().fill(.secondary.opacity(0.2)).frame(height: 1)
                    Text("veya").font(.caption).foregroundColor(.secondary).padding(.horizontal, 8)
                    Rectangle().fill(.secondary.opacity(0.2)).frame(height: 1)
                }
                .padding(.vertical, 4)
                
                // Google Butonu
                Button(action: {
                    viewModel.signInWithGoogle()
                }) {
                    HStack(spacing: 10) {
                        GoogleLogoView()
                            .frame(width: 22, height: 22)
                        
                        Text("Google ile Devam Et")
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

    private var registrationToggle: some View {
        Button(action: {
            showingRegister = true
        }) {
            HStack(spacing: 4) {
                Text("Hesabınız yok mu?")
                    .foregroundColor(.secondary)
                Text("Şimdi Kayıt Olun")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .font(.footnote)
        }
    }
    
    private func customTextField(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            TextField(title, text: text)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func customSecureField(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            SecureField(title, text: text)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.dark)
    }
}
