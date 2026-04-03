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
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.secondary)
                        Text("Bağlantı Bekleniyor...")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
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
                
                Task {
                    // Min display timing for branding
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    
                    // Wait for connection
                    while !NetworkMonitor.shared.isConnected {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            isSplashing = false
                        }
                    }
                }
            }
        }
    }
}
