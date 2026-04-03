import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showingLogin = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if !authManager.isAuthenticated {
                    unauthenticatedView
                } else {
                    authenticatedView
                }
            }
            .navigationTitle("Favorilerim")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingLogin) { LoginView() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var unauthenticatedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "star.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.blue.gradient)
            }

            VStack(spacing: 12) {
                Text("Favori Listeni Oluştur")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("Takip etmek istediğin hisse ve kripto\nvarlıkları buraya ekleyebilirsin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingLogin = true
            } label: {
                Text("Giriş Yap / Kayıt Ol")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Authenticated
    private var authenticatedView: some View {
        Group {
            if viewModel.isLoading && viewModel.favoriteCryptos.isEmpty && viewModel.favoriteStocks.isEmpty {
                loadingView
            } else if viewModel.favoriteCryptos.isEmpty && viewModel.favoriteStocks.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .task {
            if viewModel.favoriteCryptos.isEmpty && viewModel.favoriteStocks.isEmpty {
                await viewModel.loadData()
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    // MARK: - List
    private var listView: some View {
        List {
            // Connection banner
            if !viewModel.isConnected {
                reconnectBanner
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(EmptyView())
                    .padding(.vertical, 8)
            }

            if !viewModel.favoriteStocks.isEmpty {
                Section(header: favoriteSectionHeader(title: "Hisse Senetleri", icon: "chart.bar.fill", accent: .blue)) {
                    ForEach(viewModel.favoriteStocks) { stock in
                        NavigationLink(destination: StockDetailView(stock: stock)) {
                            stockRow(stock)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeFavoriteStock(stock)
                            } label: {
                                Label("Sil", systemImage: "star.slash")
                            }
                        }
                    }
                }
            }

            if !viewModel.favoriteCryptos.isEmpty {
                Section(header: favoriteSectionHeader(title: "Kripto Paralar", icon: "bitcoinsign.circle.fill", accent: .orange)) {
                    ForEach(viewModel.favoriteCryptos) { crypto in
                        NavigationLink(destination: CryptoDetailView(crypto: crypto)) {
                            cryptoRow(crypto)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeFavoriteCrypto(crypto)
                            } label: {
                                Label("Sil", systemImage: "star.slash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func favoriteSectionHeader(title: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(accent)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
        .padding(.leading, 4)
    }

    // MARK: - Rows
    private func stockRow(_ stock: Stock) -> some View {
        let isPositive = stock.changePercent.hasPrefix("+")
        let changeColor: Color = stock.changePercent == "—" ? .secondary : (isPositive ? .green : .red)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 44, height: 44)
                Text(String(stock.symbol.prefix(2)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(stock.symbol)/TL").font(.headline)
                Text(stock.description).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(stock.lastPrice != "—" ? "₺\(stock.lastPrice)" : "₺—")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(stock.changePercent)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(changeColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func cryptoRow(_ crypto: Crypto) -> some View {
        let isPositive = !crypto.priceChangePercent.hasPrefix("-")
        let changeColor: Color = isPositive ? .green : .red

        return HStack(spacing: 14) {
            CryptoLogoView(symbol: crypto.symbol, size: 44)

            let baseSymbol = crypto.symbol.replacingOccurrences(of: "USDT", with: "")
            VStack(alignment: .leading, spacing: 3) {
                Text("\(baseSymbol)/USDT").font(.headline)
                Text(baseSymbol).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCryptoPrice(crypto.lastPrice))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(formatChange(crypto.priceChangePercent))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(changeColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - States
    private var reconnectBanner: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Bağlantı yenileniyor...")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.1)
            Text("Favoriler yükleniyor...")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var emptyView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "star.slash.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow.opacity(0.6))
            }
            VStack(spacing: 8) {
                Text("Favori Bulunamadı")
                    .font(.headline)
                Text("Varlık detay sayfasından ❤️ butonuna\nbasarak favorilerine ekleyebilirsin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Formatters
    private func formatCryptoPrice(_ str: String) -> String {
        guard let val = Double(str) else { return "$—" }
        return val > 1 ? String(format: "$%.2f", val) : String(format: "$%.4f", val)
    }

    private func formatChange(_ str: String) -> String {
        guard let val = Double(str) else { return "—" }
        return String(format: "%@%.2f%%", val >= 0 ? "+" : "", val)
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FavoritesView()
            FavoritesView().preferredColorScheme(.dark)
        }
    }
}
