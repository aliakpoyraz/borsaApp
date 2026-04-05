import SwiftUI

public struct CryptoLogoView: View {
    let symbol: String
    let size: CGFloat
    
    public init(symbol: String, size: CGFloat = 44) {
        // Yaygın eklerin (suffix) büyük/küçük harf duyarsız olarak kaldırılması
        self.symbol = symbol
            .replacingOccurrences(of: "USDT", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "BUSD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "USDC", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "TRY", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.size = size
    }
    
    public var body: some View {
        // Türkiye'deki mobil ağlarda en kararlı çalışan kaynak
        let logoURL = URL(string: "https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/\(symbol.lowercased()).png")
        
        AsyncImage(url: logoURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .empty:
                placeholder
            default:
                placeholder
            }
        }
        .id(symbol) // Sembol değiştiğinde yeniden yüklemeye zorla
    }
    
    private var placeholder: some View {
        Circle()
            .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(String(symbol.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}
