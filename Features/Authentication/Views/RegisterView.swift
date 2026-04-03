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
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Hesap Oluştur")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)
                    
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
                        
                        SecureField("Şifreyi Onayla", text: $viewModel.confirmPassword)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    
                    if showingSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Kayıt Başarılı! Yönlendiriliyor...")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Button(action: {
                            Task {
                                let success = await viewModel.signUp()
                                if success {
                                    withAnimation {
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
                                .padding()
                                .background(Color.green)
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
                                Text("Google ile Kayıt Ol")
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
                    
                    Spacer()
                }
            }
            .navigationBarItems(leading: Button("İptal") {
                dismiss()
            })
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

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .preferredColorScheme(.dark)
    }
}
