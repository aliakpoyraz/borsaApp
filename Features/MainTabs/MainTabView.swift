import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CryptoHomeView()
                .tabItem {
                    Label("Kripto", systemImage: "bitcoinsign.circle")
                }

            BistHomeView()
                .tabItem {
                    Label("BIST", systemImage: "chart.line.uptrend.xyaxis")
                }

            FavoritesPlaceholderView()
                .tabItem {
                    Label("Favoriler", systemImage: "star")
                }

            PortfolioPlaceholderView()
                .tabItem {
                    Label("Varlıklarım", systemImage: "wallet.pass")
                }
        }
    }
}

struct FavoritesPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Favoriler")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Bu alan daha sonra geliştirilecek.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Favoriler")
        }
    }
}

struct PortfolioPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Varlıklarım")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Bu alan daha sonra geliştirilecek.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Varlıklarım")
        }
    }
}
