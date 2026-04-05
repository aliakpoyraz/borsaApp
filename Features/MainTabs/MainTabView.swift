import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @ObservedObject private var authManager = AuthManager.shared
    
    // Navigation Reset IDs
    @State private var bistRootId = UUID()
    @State private var cryptoRootId = UUID()
    @State private var favoritesRootId = UUID()
    @State private var portfolioRootId = UUID()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView()
                .transition(.opacity)
        } else {
            let selection = Binding<Int>(
                get: { self.selectedTab },
                set: { newValue in
                    if newValue == self.selectedTab {
                        // Double tap detected -> Reset root
                        resetTab(newValue)
                    }
                    self.selectedTab = newValue
                }
            )

            TabView(selection: selection) {
                HomeView(
                    selectedTab: $selectedTab,
                    onBistReset: { resetTab(1) },
                    onCryptoReset: { resetTab(2) },
                    onFavoritesReset: { resetTab(3) },
                    onPortfolioReset: { resetTab(4) }
                )
                .tabItem { Label("Ana Sayfa", systemImage: "house.fill") }
                .tag(0)

                BistHomeView()
                    .id(bistRootId)
                    .tabItem { Label("BIST", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(1)

                CryptoHomeView()
                    .id(cryptoRootId)
                    .tabItem { Label("Kripto", systemImage: "bitcoinsign.circle.fill") }
                    .tag(2)

                FavoritesView(
                    selectedTab: $selectedTab,
                    onBistReset: { resetTab(1) },
                    onCryptoReset: { resetTab(2) }
                )
                    .id(favoritesRootId)
                    .tabItem { Label("Favoriler", systemImage: "star.fill") }
                    .tag(3)

                PortfolioView(selectedTab: $selectedTab)
                    .id(portfolioRootId)
                    .tabItem { Label("Varlıklarım", systemImage: "briefcase.fill") }
                    .tag(4)
            }
            .tint(.blue)
            .onAppear {
                Task { await FavoritesManager.shared.loadFavorites() }
            }
            .onChange(of: authManager.isAuthenticated) { _, authenticated in
                if authenticated {
                    selectedTab = 0
                    Task { await FavoritesManager.shared.loadFavorites() }
                } else {
                    FavoritesManager.shared.clearLocalCache()
                }
            }
            .onOpenURL { url in
                if url.scheme == "borsaapp" {
                    if url.host == "favorites" {
                        resetTab(3)
                        selectedTab = 3
                    } else if url.host == "portfolio" {
                        resetTab(4)
                        selectedTab = 4
                    }
                }
            }
        }
    }

    private func resetTab(_ tab: Int) {
        impactFeedback.prepare()
        impactFeedback.impactOccurred(intensity: 0.7)
        
        switch tab {
        case 1: bistRootId = UUID()
        case 2: cryptoRootId = UUID()
        case 3: favoritesRootId = UUID()
        case 4: portfolioRootId = UUID()
        default: break
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
