import SwiftUI

struct BistHomeView: View {
    @StateObject private var viewModel = BistViewModel()
    @State private var news: [NewsItem] = []
    @State private var isLoadingNews = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    if viewModel.searchText.isEmpty {
                        dashboardView
                    } else {
                        searchResultsView
                    }
                }
            }
            .navigationTitle("Borsa İstanbul")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Hisse Ara (Örn: THYAO)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                if viewModel.stocks.isEmpty {
                    await viewModel.loadData()
                }
                await loadNews()
            }
            .refreshable {
                await viewModel.loadData()
                await loadNews()
            }
        }
    }

    // MARK: - Dashboard
    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Gecikme uyarısı
                delayBanner

                if viewModel.isLoading {
                    loadingSection
                } else if viewModel.stocks.isEmpty {
                    emptyDataSection
                } else {
                    stockSection(title: "En Çok Artanlar", icon: "arrow.up.right.circle.fill", accent: .green, stocks: viewModel.topGainers)
                    stockSection(title: "En Çok Düşenler", icon: "arrow.down.right.circle.fill", accent: .red, stocks: viewModel.topLosers)
                    stockSection(title: "En Çok İşlem Gören", icon: "flame.fill", accent: .orange, stocks: viewModel.topVolume)
                }

                // Haberler
                newsSection
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Sections
    private var delayBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.footnote)
            Text("Piyasa verileri en fazla 15 dakika gecikmelidir")
                .font(.footnote)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .foregroundColor(Color.orange)
    }

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("BIST verileri yükleniyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyDataSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Veri Alınamadı")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Piyasa kapalı veya internet bağlantısı yok.\nLütfen tekrar deneyin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.loadData() }
            } label: {
                Label("Tekrar Dene", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal)
    }

    private func stockSection(title: String, icon: String, accent: Color, stocks: [Stock]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
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

            // Horizontal scroll cards
            if stocks.isEmpty {
                HStack {
                    Text("Veri yok")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(stocks) { stock in
                            NavigationLink(destination: StockDetailView(stock: stock)) {
                                stockCard(stock, accent: accent)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private func stockCard(_ stock: Stock, accent: Color) -> some View {
        let isPositive = stock.changePercent.hasPrefix("+")
        let changeColor: Color = stock.changePercent == "—" ? .secondary : (isPositive ? .green : .red)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Symbol avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Text(String(stock.symbol.prefix(2)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(stock.changePercent)
                    .font(.caption.bold())
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(changeColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(stock.symbol)/TL")
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(stock.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Text(priceText(stock.lastPrice))
                .font(.system(.title3, design: .rounded))
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

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.blue)
                    .font(.subheadline.weight(.semibold))
                Text("Borsa & Piyasa Haberleri")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            NewsSectionView(news: news, isLoading: isLoadingNews)
        }
        .padding(.top, 4)
    }

    // MARK: - Search Results
    private var searchResultsView: some View {
        Group {
            if viewModel.isSearching {
                VStack {
                    Spacer()
                    ProgressView("Aranıyor...")
                        .padding()
                    Spacer()
                }
            } else if viewModel.displayStocks.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("'\(viewModel.searchText)' için sonuç bulunamadı")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Büyük harfle yazın: THYAO, GARAN")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.displayStocks) { stock in
                        NavigationLink(destination: StockDetailView(stock: stock)) {
                            stockListRow(stock)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func stockListRow(_ stock: Stock) -> some View {
        let isPositive = stock.changePercent.hasPrefix("+")
        let changeColor: Color = stock.changePercent == "—" ? .secondary : (isPositive ? .green : .red)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Text(String(stock.symbol.prefix(2)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stock.symbol)
                    .font(.headline)
                Text(stock.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(priceText(stock.lastPrice))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                Text(stock.changePercent)
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

    // MARK: - Helpers
    private func priceText(_ raw: String) -> String {
        guard raw != "—", let val = Double(raw.replacingOccurrences(of: ",", with: ".")) else {
            return raw
        }
        return String(format: "₺%.2f", val)
    }

    private func loadNews() async {
        isLoadingNews = true
        news = await NewsService.shared.fetchBistNews()
        isLoadingNews = false
    }
}

struct BistHomeView_Previews: PreviewProvider {
    static var previews: some View {
        BistHomeView()
    }
}
