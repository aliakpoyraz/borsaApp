import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: Int
    let onBistReset: () -> Void
    let onCryptoReset: () -> Void
    let onFavoritesReset: () -> Void
    let onPortfolioReset: () -> Void
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showingLogin = false
    @State private var startWithRegister = false
    @AppStorage("isBalanceHidden") private var isBalanceHidden = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Portföy Özeti (Hero Card)
                        balanceHeroCard

                        // Hızlı İşlemler
                        quickActions

                        // Piyasa Bölümleri
                        if viewModel.isLoading && viewModel.cryptos.isEmpty {
                            loadingView
                        } else {
                            if !viewModel.cryptos.isEmpty {
                                marketSection(
                                    title: "Popüler Kriptolar",
                                    icon: "bitcoinsign.circle.fill",
                                    accent: .orange
                                ) {
                                    onCryptoReset()
                                    selectedTab = 2
                                } cards: {
                                    ForEach(viewModel.cryptos.prefix(8)) { crypto in
                                        NavigationLink(destination: CryptoDetailView(crypto: crypto)) {
                                            cryptoCard(crypto)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }

                            if !viewModel.stocks.isEmpty {
                                marketSection(
                                    title: "Popüler Hisseler",
                                    icon: "chart.line.uptrend.xyaxis",
                                    accent: .blue
                                ) {
                                    onBistReset()
                                    selectedTab = 1
                                } cards: {
                                    ForEach(viewModel.stocks.prefix(8)) { stock in
                                        NavigationLink(destination: StockDetailView(stock: stock)) {
                                            stockCard(stock)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Ana Sayfa")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isAuthenticated {
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLogin) {
                LoginView(startWithRegister: startWithRegister)
            }
            .onChange(of: isBalanceHidden) { oldValue, newValue in
                WidgetDataBridge.shared.syncBalanceVisibility(isHidden: newValue)
            }
        }
    }

    // MARK: - Bakiye Kartı (Balance Card)
    private var balanceHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(authManager.isAuthenticated ? "Portföy Değeri" : "BorsaApp")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(0.3)
                        
                        if authManager.isAuthenticated {
                            Button {
                                isBalanceHidden.toggle()
                            } label: {
                                Image(systemName: isBalanceHidden ? "eye.slash" : "eye")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }

                    if authManager.isAuthenticated {
                        Text(isBalanceHidden ? "****" : viewModel.formatPrice(amount: viewModel.portfolioBalance))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    } else {
                        Text("Hoş Geldiniz")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: authManager.isAuthenticated ? "briefcase.fill" : "chart.xyaxis.line")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            if authManager.isAuthenticated {
                Divider()
                    .background(Color.white.opacity(0.25))

                HStack(spacing: 20) {
                    statPill(label: "Hisse", value: "\(viewModel.portfolioStockCount)", icon: "building.columns")
                    statPill(label: "Kripto", value: "\(viewModel.portfolioCryptoCount)", icon: "bitcoinsign")
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        startWithRegister = false
                        showingLogin = true
                    } label: {
                        HStack {
                            Text("Giriş Yap")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(Capsule())
                    }

                    Button {
                        startWithRegister = true
                        showingLogin = true
                    } label: {
                        HStack {
                            Text("Kayıt Ol")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(22)
        .background(Color.blue.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.blue.opacity(0.35), radius: 16, x: 0, y: 8)
        .padding(.horizontal)
    }

    private func statPill(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Hızlı İşlemler (Quick Actions)
    private var quickActions: some View {
        HStack(spacing: 0) {
            quickActionTile(icon: "bitcoinsign.circle.fill", title: "Kripto", color: .orange) { 
                onCryptoReset()
                selectedTab = 2 
            }
            Divider().frame(height: 44)
            quickActionTile(icon: "chart.bar.fill", title: "Borsa", color: .blue) { 
                onBistReset()
                selectedTab = 1 
            }
            Divider().frame(height: 44)
            quickActionTile(icon: "star.fill", title: "Favoriler", color: .yellow) { 
                onFavoritesReset()
                selectedTab = 3 
            }
            Divider().frame(height: 44)
            quickActionTile(icon: "briefcase.fill", title: "Varlıklar", color: .purple) { 
                onPortfolioReset()
                selectedTab = 4 
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func quickActionTile(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Piyasa Bölümü (Market Section)
    private func marketSection<Cards: View>(
        title: String,
        icon: String,
        accent: Color,
        onSeeAll: @escaping () -> Void,
        @ViewBuilder cards: @escaping () -> Cards
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Tümü") {
                    onSeeAll()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    cards()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Kartlar (Cards)
    private func cryptoCard(_ crypto: Crypto) -> some View {
        let isPositive = !crypto.priceChangePercent.hasPrefix("-")
        let changeColor: Color = isPositive ? .green : .red
        let baseSymbol = crypto.symbol.replacingOccurrences(of: "USDT", with: "")
        let displaySymbol = "\(baseSymbol)/USDT"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                CryptoLogoView(symbol: baseSymbol, size: 32)
                Spacer()
                Text(viewModel.formatChange(crypto.priceChangePercent))
                    .font(.caption2.bold())
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(changeColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(displaySymbol)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
            Text(viewModel.formatCryptoPrice(crypto.lastPrice))
                .font(.footnote.weight(.semibold))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(width: 140)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func stockCard(_ stock: Stock) -> some View {
        let isPositive = stock.changePercent.hasPrefix("+")
        let changeColor: Color = stock.changePercent == "—" ? .secondary : (isPositive ? .green : .red)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Text(String(stock.symbol.prefix(2)))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(stock.changePercent)
                    .font(.caption2.bold())
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(changeColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text("\(stock.symbol)/TL")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
            Text(stock.lastPrice != "—" ? "₺\(stock.lastPrice)" : "—")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(width: 140)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Piyasalar yükleniyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView(selectedTab: .constant(0), onBistReset: {}, onCryptoReset: {}, onFavoritesReset: {}, onPortfolioReset: {})
            HomeView(selectedTab: .constant(0), onBistReset: {}, onCryptoReset: {}, onFavoritesReset: {}, onPortfolioReset: {}).preferredColorScheme(.dark)
        }
    }
}
