import SwiftUI

struct CryptoDetailView: View {
    let crypto: Crypto
    @StateObject private var favorites = FavoritesManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedPeriod = "1G"
    @State private var showingAlertPopup = false
    @State private var historicalData: [Double] = []
    @State private var isChartLoading = true
    @State private var showLoginPrompt = false
    
    // Alerts & Trend
    @State private var activeAlerts: [Alert] = []
    private let alertService = AlertService.live()
    private let trendService = TrendService.shared
    
    // Live Data Support
    @State private var livePrice: String = ""
    @State private var liveChange: String = ""
    @State private var livePriceChange: String = ""
    @State private var liveTask: Task<Void, Never>?

    let baseSymbol: String
    private var isPositive: Bool { (Double(liveChange) ?? 0) >= 0 }
    private var changeColor: Color { isPositive ? .green : .red }
    
    private var marketTrend: MarketTrend {
        let decimal = Decimal(string: liveChange) ?? 0
        return trendService.calculateTrend(priceChangePercent: decimal)
    }

    init(crypto: Crypto) {
        self.crypto = crypto
        self.baseSymbol = crypto.symbol
            .replacingOccurrences(of: "USDT", with: "")
            .replacingOccurrences(of: "BUSD", with: "")
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroHeader
                    priceCard
                    chartSection
                    
                    if authManager.isAuthenticated {
                        activeAlertsSection
                    }
                    
                    marketDataGrid
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .refreshable {
                loadHistoricalData()
                loadAlerts()
                startLiveUpdates()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(baseSymbol)
        .sheet(isPresented: $showingAlertPopup) {
            AlertCreationView(symbol: crypto.symbol, currentPrice: livePrice)
                .onDisappear { loadAlerts() }
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginView()
        }
        .task { 
            self.livePrice = crypto.lastPrice
            self.liveChange = crypto.priceChangePercent
            self.livePriceChange = crypto.priceChange
            loadHistoricalData() 
            startLiveUpdates()
            loadAlerts()
        }
        .onDisappear {
            liveTask?.cancel()
        }
        .onReceive(WebSocketClient.shared.pricePublisher) { tick in
            if tick.symbol.uppercased() == crypto.symbol.uppercased() {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.livePrice = tick.price
                    if let p = tick.priceChangePercent {
                        self.liveChange = p
                    }
                    if let pc = tick.priceChange {
                        self.livePriceChange = pc
                    }
                }
            }
        }
    }
    
    private func startLiveUpdates() {
        liveTask?.cancel()
        liveTask = Task {
            await WebSocketClient.shared.connect()
            await WebSocketClient.shared.subscribe(symbols: [crypto.symbol])
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        HStack(spacing: 14) {
            // Logo
            CryptoLogoView(symbol: crypto.symbol, size: 52)
                .shadow(color: changeColor.opacity(0.3), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(baseSymbol)/USDT")
                        .font(.headline)
                    
                    // Trend Badge
                    HStack(spacing: 4) {
                        Image(systemName: marketTrend.icon)
                        Text(marketTrend.rawValue)
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(marketTrend.color)
                    .clipShape(Capsule())
                }
                
                Text(crypto.symbol)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                actionButton(icon: "bell.badge.fill", color: .orange) {
                    if authManager.isAuthenticated {
                        showingAlertPopup = true
                    } else {
                        showLoginPrompt = true
                    }
                }

                actionButton(
                    icon: favorites.isCryptoFavorite(crypto.symbol) ? "heart.fill" : "heart",
                    color: .red
                ) {
                    if authManager.isAuthenticated {
                        favorites.toggleCryptoFavorite(crypto.symbol)
                    } else {
                        showLoginPrompt = true
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(Circle())
        }
    }

    // MARK: - Price Card
    private var priceCard: some View {
        let displayChange = crypto.priceChangePercent.hasPrefix("-")
            ? crypto.priceChangePercent
            : (crypto.priceChangePercent.hasPrefix("+") ? crypto.priceChangePercent : "+\(crypto.priceChangePercent)")

        return VStack(spacing: 8) {
            Text(formatPrice(livePrice))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()

            HStack(spacing: 8) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.bold))
                Text("\(displayChange)%")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundColor(changeColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(changeColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(spacing: 12) {
            // Period picker
            Picker("Zaman Dilimi", selection: $selectedPeriod) {
                Text("1G").tag("1G")
                Text("1H").tag("1H")
                Text("1A").tag("1A")
                Text("1Y").tag("1Y")
                Text("Tümü").tag("Tümü")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedPeriod) { _, _ in
                isChartLoading = true
                loadHistoricalData()
            }

            // Chart
            Group {
                if isChartLoading {
                    ProgressView()
                        .frame(height: 220)
                } else if historicalData.isEmpty {
                    VStack(spacing: 8) {
                        let displaySymbol = "\(crypto.symbol.replacingOccurrences(of: "USDT", with: ""))/USDT"
                        Text(displaySymbol)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary).opacity(0.4)
                        TextField("0", text: .constant(""))
                            .keyboardType(.decimalPad)
                            .font(.system(.title3, design: .rounded).bold())
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(height: 220)
                } else {
                    ChartView(dataPoints: historicalData, lineColor: changeColor)
                        .frame(height: 220)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Market Data
    private var marketDataGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.blue)
                    .font(.subheadline.weight(.semibold))
                Text("Piyasa Verileri")
                    .font(.headline)
            }
            .padding(.horizontal)

            // Trend card
            let trend = trendService.calculateTrend(priceChangePercent: Decimal(string: liveChange) ?? 0)
            trendCard(trend: trend)
                .padding(.horizontal)

            // Stats grid
            VStack(spacing: 10) {
                    statCard(icon: "chart.bar.fill", title: "Hacim (Birim)", value: formatAmount(crypto.volume), accent: .blue)
                    statCard(icon: "arrow.up.right.circle.fill", title: "24s Değişim ($)", value: formatPrice(livePriceChange), accent: .purple)
                HStack(spacing: 10) {
                    let currentVal = Double(livePrice) ?? 0
                    let highVal = Double(crypto.highPrice) ?? 0
                    let lowVal = Double(crypto.lowPrice) ?? 0
                    
                    statCard(icon: "arrow.up.circle.fill", title: "24s Yüksek", value: formatPrice(currentVal > highVal ? livePrice : crypto.highPrice), accent: .green)
                    statCard(icon: "arrow.down.circle.fill", title: "24s Düşük", value: formatPrice((currentVal < lowVal && currentVal != 0) ? livePrice : crypto.lowPrice), accent: .red)

                }
            }
            .padding(.horizontal)
        }
    }

    private func trendCard(trend: MarketTrend) -> some View {
        return HStack(spacing: 12) {
            Image(systemName: trend.icon)
                .font(.title3.weight(.semibold))
                .foregroundColor(trend.color)
                .frame(width: 40, height: 40)
                .background(trend.color.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Algoritma Eğilimi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(trend.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(trend.color)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statCard(icon: String, title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(accent)
                .frame(width: 32, height: 32)
                .background(accent.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // REMOVED legacy trend helpers

    private func loadHistoricalData() {
        Task {
            do {
                let service = CryptoService()
                let data = try await service.fetchHistoricalPrices(symbol: crypto.symbol, period: selectedPeriod)
                await MainActor.run {
                    self.historicalData = data
                    self.isChartLoading = false
                }
            } catch {
                await MainActor.run {
                    self.historicalData = []
                    self.isChartLoading = false
                }
            }
        }
    }


    private func formatPrice(_ price: String) -> String {
        guard let val = Double(price) else { return "$0.00" }
        if val >= 1 {
            return String(format: "$%.2f", val)
        } else if val >= 0.0001 {
            return String(format: "$%.4f", val)
        } else {
            return "$ " + String(format: "%.8f", val)
        }
    }

    private func formatAmount(_ amount: String) -> String {
        guard let val = Double(amount) else { return "0" }
        if val > 1_000_000_000 { return String(format: "%.2fB", val / 1_000_000_000) }
        if val > 1_000_000 { return String(format: "%.2fM", val / 1_000_000) }
        if val > 1_000 { return String(format: "%.2fK", val / 1_000) }
        return String(format: "%.0f", val)
    }

    // MARK: - Active Alerts
    private var activeAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Aktif Alarmlar", systemImage: "bell.badge.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showingAlertPopup = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 4)

            if activeAlerts.isEmpty {
                Text("Bu varlık için kurulmuş bir alarm bulunmuyor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 1) {
                    ForEach(activeAlerts) { alert in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fiyat $\(String(describing: alert.targetPrice)) \(alert.isAbove ? "üstüne çıkınca" : "altına inince")")
                                    .font(.subheadline.weight(.medium))
                                Text("Lokal Bildirim")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                Task {
                                    await alertService.removeAlert(id: alert.id)
                                    loadAlerts()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
    }

    private func loadAlerts() {
        Task {
            let allAlerts = await alertService.getAlerts()
            let normalizedSym = crypto.symbol.uppercased()
            self.activeAlerts = allAlerts.filter { $0.symbol.uppercased() == normalizedSym && $0.isActive }
        }
    }
}
