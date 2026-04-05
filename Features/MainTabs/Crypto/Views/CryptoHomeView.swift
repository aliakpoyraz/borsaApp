import SwiftUI

struct CryptoHomeView: View {
    @StateObject private var viewModel = CryptoViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var news: [NewsItem] = []
    @State private var isLoadingNews = false
    @State private var showingLogin = false

    // Kripto teması için turuncu/kırmızı gradyan (accent)
    private let cryptoGradient = LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.cryptos.isEmpty {
                        loadingView
                    } else if let error = viewModel.errorMessage, viewModel.cryptos.isEmpty {
                        errorView(error: error)
                    } else if viewModel.searchText.isEmpty {
                        dashboardView
                    } else {
                        searchResultsView
                    }
                }
            }
            .navigationTitle("Kripto Paralar")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Kripto ara (BTC, ETH...)")
            .task {
                if viewModel.cryptos.isEmpty {
                    await viewModel.loadData()
                }
                await loadNews()
            }
            .refreshable {
                await viewModel.loadData()
                await loadNews()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isAuthenticated {
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Giriş Yap") {
                            showingLogin = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
        }
    }

    // MARK: - Kontrol Paneli (Dashboard)
    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                cryptoSection(title: "Popüler", icon: "star.circle.fill", accent: .yellow, cryptos: viewModel.topPopular)
                cryptoSection(title: "En Çok Artanlar", icon: "arrow.up.right.circle.fill", accent: .green, cryptos: viewModel.topGainers)
                cryptoSection(title: "En Çok Düşenler", icon: "arrow.down.right.circle.fill", accent: .red, cryptos: viewModel.topLosers)
                cryptoSection(title: "Yüksek Hacimli", icon: "flame.fill", accent: .orange, cryptos: viewModel.topVolume)

                // Kripto Haberleri
                newsSection
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Kripto Bölümü (Crypto Section)
    private func cryptoSection(title: String, icon: String, accent: Color, cryptos: [Crypto]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cryptos) { crypto in
                        NavigationLink(destination: CryptoDetailView(crypto: crypto)) {
                            cryptoCard(crypto, accent: accent)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }

    private func cryptoCard(_ crypto: Crypto, accent: Color) -> some View {
        let isPositive = crypto.priceChangePercent.hasPrefix("+") || (!crypto.priceChangePercent.hasPrefix("-") && crypto.priceChangePercent != "0.000")
        let changeColor: Color = isPositive ? .green : .red
        let baseSymbol = crypto.symbol.replacingOccurrences(of: "USDT", with: "").replacingOccurrences(of: "BUSD", with: "")

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Logo
                CryptoLogoView(symbol: baseSymbol, size: 36)
                Spacer()
                Text(viewModel.formatChange(crypto.priceChangePercent))
                    .font(.caption.bold())
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(changeColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(baseSymbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)
                Text(crypto.symbol)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(viewModel.formatPrice(crypto.lastPrice))
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(width: 155)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Arama Sonuçları (Search Results)
    private var searchResultsView: some View {
        List {
            ForEach(viewModel.filteredCryptos) { crypto in
                NavigationLink(destination: CryptoDetailView(crypto: crypto)) {
                    cryptoListRow(crypto)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func cryptoListRow(_ crypto: Crypto) -> some View {
        let isPositive = crypto.priceChangePercent.hasPrefix("+") || (!crypto.priceChangePercent.hasPrefix("-") && crypto.priceChangePercent != "0.000")
        let changeColor: Color = isPositive ? .green : .red
        let baseSymbol = crypto.symbol.replacingOccurrences(of: "USDT", with: "").replacingOccurrences(of: "BUSD", with: "")

        return HStack(spacing: 12) {
            CryptoLogoView(symbol: baseSymbol, size: 40)

            let baseSymbol = crypto.symbol.replacingOccurrences(of: "USDT", with: "")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(baseSymbol)/USDT")
                    .font(.headline)
                Text(baseSymbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.formatPrice(crypto.lastPrice))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                Text(viewModel.formatChange(crypto.priceChangePercent))
                    .font(.caption.bold())
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(changeColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Logo Bileşeni (Logo)
    @ViewBuilder
    private func cryptoLogo(symbol: String, size: CGFloat) -> some View {
        let logoURL = URL(string: "https://assets.coincap.io/assets/icons/\(symbol.lowercased())@2x.png")
        AsyncImage(url: logoURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            default:
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(symbol.prefix(1)))
                            .font(.system(size: size * 0.38, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    // MARK: - Haberler (News)
    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline.weight(.semibold))
                Text("Kripto Haberleri")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            NewsSectionView(news: news, isLoading: isLoadingNews)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Durum Görünümleri (States)
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Kripto veriler yükleniyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Yükleme Hatası")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Tekrar Dene") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    private func loadNews() async {
        isLoadingNews = true
        news = await NewsService.shared.fetchCryptoNews()
        isLoadingNews = false
    }
}
