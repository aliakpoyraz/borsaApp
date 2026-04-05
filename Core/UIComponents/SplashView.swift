import SwiftUI

struct SplashView: View {
    @Binding var isSplashing: Bool
    @ObservedObject private var network = NetworkMonitor.shared
    
    @State private var scale = 0.7
    @State private var opacity = 0.0
    @State private var blur: CGFloat = 20
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            // Subtle premium background glow
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(y: -50)
                .opacity(opacity)
            
            VStack(spacing: 32) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 15)
                    .scaleEffect(scale)
                    .blur(radius: blur)
                
                if !network.isConnected {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                        
                        Text("İnternet bağlantınız yok")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Lütfen bağlantınızı kontrol edin ve tekrar deneyin.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            checkConnectionAndProceed()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Yeniden Dene")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if opacity == 1.0 { // Sadece her şey görünürken ve internet varken
                    ProgressView()
                        .tint(.secondary)
                }
            }
            .opacity(opacity)
            .onAppear {
                // Premium Spring Animation
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 15).delay(0.2)) {
                    self.scale = 1.0
                    self.blur = 0
                }
                
                withAnimation(.easeIn(duration: 0.8).delay(0.1)) {
                    self.opacity = 1.0
                }
                
                checkConnectionAndProceed(delay: 1.5)
            }
            .onChange(of: network.isConnected) { _, isConnected in
                if isConnected {
                    checkConnectionAndProceed(delay: 0.5)
                }
            }
        }
    }

    private func checkConnectionAndProceed(delay: Double = 1.5) {
        Task {
            // Min display timing for branding
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            if NetworkMonitor.shared.isConnected {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isSplashing = false
                    }
                }
            }
        }
    }
}
