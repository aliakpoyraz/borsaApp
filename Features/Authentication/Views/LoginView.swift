import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingRegister = false
    @ObservedObject private var authManager = AuthManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "lock.shield")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("Hoş Geldiniz")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 16) {
                        TextField("E-posta", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        SecureField("Şifre", text: $viewModel.password)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
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
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Google Sign-In Button
                        Button(action: {
                            viewModel.signInWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text("Google ile Giriş Yap")
                                    .font(.headline)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        showingRegister = true
                    }) {
                        Text("Hesabın yok mu? Kayıt Ol")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
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
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.dark)
    }
}
