import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView()
                .transition(.opacity)
        } else {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem { Label("Ana Sayfa", systemImage: "house.fill") }
                    .tag(0)

                BistHomeView()
                    .tabItem { Label("BIST", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(1)

                CryptoHomeView()
                    .tabItem { Label("Kripto", systemImage: "bitcoinsign.circle.fill") }
                    .tag(2)

                FavoritesView()
                    .tabItem { Label("Favoriler", systemImage: "star.fill") }
                    .tag(3)

                PortfolioView()
                    .tabItem { Label("Varlıklarım", systemImage: "briefcase.fill") }
                    .tag(4)
            }
            .tint(.blue)
            .onAppear {
                Task { await FavoritesManager.shared.loadFavorites() }
            }
            .onChange(of: authManager.isAuthenticated) { _, authenticated in
                if authenticated {
                    Task { await FavoritesManager.shared.loadFavorites() }
                } else {
                    FavoritesManager.shared.clearLocalCache()
                }
            }
            .onOpenURL { url in
                if url.scheme == "borsaapp" {
                    if url.host == "favorites" {
                        selectedTab = 3
                    } else if url.host == "portfolio" {
                        selectedTab = 4
                    }
                }
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
