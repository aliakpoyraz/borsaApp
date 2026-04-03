import SwiftUI

struct ReconnectingView: View {
    var isConnected: Bool
    
    var body: some View {
        if !isConnected {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                
                Text("Bağlanıyor...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.8))
            .cornerRadius(16)
            .shadow(radius: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: isConnected)
        }
    }
}

// Preview için
struct ReconnectingView_Previews: PreviewProvider {
    static var previews: some View {
        ReconnectingView(isConnected: false)
            .preferredColorScheme(.dark)
    }
}
