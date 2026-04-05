import SwiftUI

struct StockDetailView: View {
    let stock: Stock
    @StateObject private var favorites = FavoritesManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedPeriod = "1G"
    @State private var showingAlertPopup = false
    @State private var historicalData: [Double] = []
    @State private var isChartLoading = true
    @State private var showLoginPrompt = false
    @ObservedObject private var network = NetworkMonitor.shared
    
    // Alarmlar
    @State private var activeAlerts: [Alert] = []
    private let alertService = AlertService.live()
    private let trendService = TrendService.shared
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    // KALDIRILDI: Çalışmayan finansal veriler


    private var isPositive: Bool { stock.changePercent.hasPrefix("+") }
    private var changeColor: Color { stock.changePercent == "—" ? .secondary : (isPositive ? .green : .red) }
    private var displayChange: String {
        guard stock.changePercent != "—" else { return "—" }
        return stock.changePercent.hasPrefix("-") || stock.changePercent.hasPrefix("+")
            ? stock.changePercent : "+\(stock.changePercent)"
    }
    
    private var marketTrend: MarketTrend {
        let clean = stock.changePercent.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "%", with: "")
        let decimal = Decimal(string: clean) ?? 0
        return trendService.calculateTrend(priceChangePercent: decimal)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if !network.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                            Text("İnternet bağlantınız yok")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
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
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(stock.symbol)
        .sheet(isPresented: $showingAlertPopup) {
            AlertCreationView(symbol: stock.symbol, currentPrice: stock.lastPrice)
                .onDisappear { loadAlerts() }
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginView()
        }
        .task {
            loadHistoricalData()
            loadAlerts()
        }
    }

    // MARK: - Ana Başlık (Hero Header)
    private var heroHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.8), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8)
                Text(String(stock.symbol.prefix(2)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(stock.symbol)/TL")
                        .font(.headline)
                    
                    // Trend Rozeti (Badge)
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
                
                Text(stock.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                // Alarm Butonu
                actionButton(icon: "bell.badge.fill", color: .orange) {
                    if authManager.isAuthenticated {
                        showingAlertPopup = true
                    } else {
                        showLoginPrompt = true
                    }
                }

                // Favori Butonu
                Button {
                    if authManager.isAuthenticated {
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                        favorites.toggleStockFavorite(stock.symbol)
                    } else {
                        showLoginPrompt = true
                    }
                } label: {
                    Image(systemName: favorites.isStockFavorite(stock.symbol) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(favorites.isStockFavorite(stock.symbol) ? .red : .secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Aktif Alarmlar Section
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
                        .foregroundColor(.blue)
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
                                Text("Fiyat ₺\(String(describing: alert.targetPrice)) \(alert.isAbove ? "üstüne çıkınca" : "altına inince")")
                                    .font(.subheadline.weight(.medium))
                                Text("Fiyat Bildirimi")
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
            self.activeAlerts = allAlerts.filter { $0.symbol.uppercased() == stock.symbol.uppercased() && $0.isActive }
        }
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

    // MARK: - Fiyat Kartı
    private var priceCard: some View {
        VStack(spacing: 8) {
            Text(formatPrice(stock.lastPrice))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()

            HStack(spacing: 8) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.bold))
                Text(displayChange)
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

    // MARK: - Grafik Bölümü (Chart Section)
    private var chartSection: some View {
        VStack(spacing: 12) {
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

            Group {
                if isChartLoading {
                    ProgressView().frame(height: 220)
                } else if historicalData.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Grafik verisi bulunamadı")
                            .font(.subheadline).foregroundColor(.secondary)
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

    // MARK: - Piyasa Verileri (Market Data)
    private var marketDataGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(.blue)
                    .font(.subheadline.weight(.semibold))
                Text("Piyasa Verileri")
                    .font(.headline)
            }
            .padding(.horizontal)

            // Trend kartı
            trendCard(trend: marketTrend)
                .padding(.horizontal)

            // Stats grid
            // Stats grid
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    statCard(icon: "arrow.up.circle.fill", title: "En Yüksek (24S)", value: formatPrice(stock.highPrice), accent: .green)
                    statCard(icon: "arrow.down.circle.fill", title: "En Düşük (24S)", value: formatPrice(stock.lowPrice), accent: .red)
                }
                HStack(spacing: 10) {
                    statCard(icon: "chart.bar.fill", title: "Günlük Aralık", value: "₺\(stock.lowPrice) - ₺\(stock.highPrice)", accent: .blue)
                    statCard(icon: "chart.bar.xaxis", title: "24s Hacim", value: stock.volume, accent: .teal)
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
                    .font(.caption).foregroundColor(.secondary)
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
                Text(title).font(.caption).foregroundColor(.secondary).lineLimit(1)
                Text(value).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                    .minimumScaleFactor(0.8).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // KALDIRILDI: Eski trend yardımcıları

    private func loadHistoricalData() {
        Task {
            do {
                let data = try await BistService.shared.fetchHistoricalPrices(symbol: stock.symbol, period: selectedPeriod)
                await MainActor.run { self.historicalData = data; self.isChartLoading = false }
            } catch {
                await MainActor.run { self.historicalData = []; self.isChartLoading = false }
            }
        }
    }

    private func formatPrice(_ raw: String) -> String {
        let clean = raw.replacingOccurrences(of: ",", with: ".")
        guard let val = Double(clean) else { return "₺—" }
        return String(format: "₺%.2f", val)
    }

}
