import SwiftUI

struct PortfolioView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = PortfolioViewModel()
    @ObservedObject private var authManager = AuthManager.shared
    @AppStorage("isBalanceHidden") private var isBalanceHidden = false
    @State private var showingLogin = false
    @State private var startWithRegister = false
    @State private var showingAddAsset = false
    @State private var selectedAssetToEdit: PortfolioAssetPnL?

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
            .navigationTitle("Varlıklarım")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 4) {
                            NavigationLink(destination: ProfileView()) {
                                Image(systemName: "person.circle")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            Button {
                                showingAddAsset = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    }
                }
            .sheet(isPresented: $showingLogin) {
                LoginView(startWithRegister: startWithRegister)
            }
            .sheet(isPresented: $showingAddAsset) {
                PortfolioAddAssetView(viewModel: viewModel)
            }
            .sheet(item: $selectedAssetToEdit) { asset in
                PortfolioEditAssetView(viewModel: viewModel, asset: asset)
            }
            .onChange(of: isBalanceHidden) { oldValue, newValue in
                WidgetDataBridge.shared.syncBalanceVisibility(isHidden: newValue)
            }
        }
    }

    // MARK: - Kimliği Doğrulanmamış Görünüm (Unauthenticated)
    private var unauthenticatedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.blue.gradient)
            }

            VStack(spacing: 12) {
                Text("Portföyünüzü Yönetin")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("Hisse ve kripto varlıklarınızı takip\netmek için giriş yapın veya kayıt olun.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 12) {
                Button {
                    startWithRegister = false
                    showingLogin = true
                } label: {
                    Text("Giriş Yap")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    startWithRegister = true
                    showingLogin = true
                } label: {
                    Text("Kayıt Ol")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Kimliği Doğrulanmış Görünüm (Authenticated)
    private var authenticatedView: some View {
        List {
            // Üst bilgi benzeri bir satır olarak ana bakiye kartı
            Section {
                balanceHeroCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(EmptyView())
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }

            if viewModel.isLoading && viewModel.assetsWithPnL.isEmpty {
                Section {
                    loadingView
                        .listRowBackground(EmptyView())
                }
            } else if let error = viewModel.errorMessage {
                Section {
                    errorView(error: error)
                        .listRowBackground(EmptyView())
                }
            } else if viewModel.assetsWithPnL.isEmpty {
                Section {
                    emptyPortfolioView
                        .listRowBackground(EmptyView())
                }
            } else {
                let stocks = viewModel.assetsWithPnL.filter { $0.kind == .stock }
                let cryptos = viewModel.assetsWithPnL.filter { $0.kind == .crypto }

                // Hisse Senetleri Bölümü (Stocks Section)
                if !stocks.isEmpty {
                    Section(header: categoryHeader(title: "Hisse Senetleri", icon: "chart.bar.fill", color: .blue)) {
                        ForEach(stocks) { asset in
                            assetRow(asset)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeAsset(asset: asset) }
                                } label: {
                                    Label("Sil", systemImage: "trash.fill")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    selectedAssetToEdit = asset
                                } label: {
                                    Label("Düzenle", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }

                // Kripto Paralar Bölümü (Cryptos Section)
                if !cryptos.isEmpty {
                    Section(header: categoryHeader(title: "Kripto Paralar", icon: "bitcoinsign.circle.fill", color: .orange)) {
                        ForEach(cryptos) { asset in
                            assetRow(asset)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeAsset(asset: asset) }
                                } label: {
                                    Label("Sil", systemImage: "trash.fill")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    selectedAssetToEdit = asset
                                } label: {
                                    Label("Düzenle", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
        .onAppear {
            viewModel.startRefreshTimer()
        }
        .onDisappear {
            viewModel.stopRefreshTimer()
        }
    }

    private func categoryHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.leading, 4)
    }

    // MARK: - Bakiye Kartı (Balance Card)
    private var balanceHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Toplam Portföy Değeri")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(0.3)

                        Button {
                            isBalanceHidden.toggle()
                        } label: {
                            Image(systemName: isBalanceHidden ? "eye.slash" : "eye")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Text(isBalanceHidden ? "****" : viewModel.formatAmount(viewModel.totalBalance))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(22)
        .background(Color.blue.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.blue.opacity(0.35), radius: 16, x: 0, y: 8)
        .padding(.horizontal)
    }

    // MARK: - Varlık Satırı (swipe-deletable)
    private func assetRow(_ asset: PortfolioAssetPnL) -> some View {
        let baseSymbol = asset.symbol.replacingOccurrences(of: "USDT", with: "").replacingOccurrences(of: "BUSD", with: "")

        return HStack(spacing: 14) {
            // Logo/İkon
            if asset.kind == .crypto {
                CryptoLogoView(symbol: baseSymbol, size: 44)
            } else {
                gradientCircle(symbol: baseSymbol, colors: [.blue, .cyan])
            }

            // İsim ve Miktar
            VStack(alignment: .leading, spacing: 3) {
                let displaySymbol = asset.kind == .crypto ? "\(baseSymbol)/USDT" : "\(baseSymbol)/TL"
                Text(displaySymbol)
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.primary)
                Text(quantityText(asset))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Değer Bilgisi
            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.formatAmount(asset.totalValueTL(rate: viewModel.usdToTryRate)))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                
                if asset.kind == .crypto {
                    Text(viewModel.formatCryptoPrice("\(asset.currentPrice)"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Hisse")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func assetIcon(kind: PortfolioAssetKind, symbol: String) -> some View {
        if kind == .crypto {
            CryptoLogoView(symbol: symbol, size: 44)
        } else {
            gradientCircle(symbol: symbol, colors: [.blue, .cyan])
        }
    }

    private func gradientCircle(symbol: String, colors: [Color]) -> some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(symbol.prefix(2)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func quantityText(_ asset: PortfolioAssetPnL) -> String {
        let qty = NSDecimalNumber(decimal: asset.quantity).doubleValue
        if qty < 0.0001 {
            return String(format: "%.8f Adet", qty)
        } else if qty < 1 {
            return String(format: "%.6f Adet", qty)
        } else {
            return String(format: "%.4f Adet", qty)
        }
    }

    private func stockFor(asset: PortfolioAssetPnL) -> Stock {
        Stock(
            symbol: asset.symbol,
            description: asset.symbol,
            lastPrice: "\(asset.currentPrice)",
            changePercent: "0%",
            volume: "0",
            highPrice: "\(asset.currentPrice)",
            lowPrice: "\(asset.currentPrice)"
        )
    }

    private func cryptoFor(asset: PortfolioAssetPnL) -> Crypto {
        Crypto(
            symbol: asset.symbol,
            lastPrice: "\(asset.currentPrice)",
            priceChangePercent: "0%",
            highPrice: "\(asset.currentPrice)",
            lowPrice: "\(asset.currentPrice)",
            volume: "0"
        )
    }

    // MARK: - Durum Görünümleri (States)
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Portföy yükleniyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Yükleme Hatası")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Tekrar Dene") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var emptyPortfolioView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.blue.gradient)
            }

            VStack(spacing: 8) {
                Text("Henüz Varlık Eklenmedi")
                    .font(.headline)
                Text("Sağ üstteki + butonuna tıklayarak\nilk varlığınızı ekleyebilirsiniz.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAddAsset = true
            } label: {
                Label("Varlık Ekle", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.blue.gradient)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal)
    }
}


struct PortfolioView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PortfolioView(selectedTab: .constant(4))
            PortfolioView(selectedTab: .constant(4)).preferredColorScheme(.dark)
        }
    }
}
