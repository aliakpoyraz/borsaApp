
import SwiftUI
import BackgroundTasks
import GoogleSignIn

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "Sistem Varsayılanı"
        case .light:  return "Aydınlık"
        case .dark:   return "Karanlık"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@main
struct BorsaTakipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    private let alertService = AlertService.live()

    var body: some Scene {
        WindowGroup {
            RootView(alertService: alertService)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceModeRaw)?.preferredColorScheme ?? nil)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .background {
                scheduleAppRefresh()
                Task {
                    await syncWidgets()
                }
            }
        }
        // iOS 16+ Background Task API
        .backgroundTask(.appRefresh("com.borsaApp.priceCheck")) {
            await scheduleAppRefresh()
            await checkPricesAndAlert()
        }
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.borsaApp.priceCheck")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 dk aralıklar
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Background Task scheduling error: \(error)")
        }
    }
    
    private func checkPricesAndAlert() async {
        let cryptoService = CryptoService.shared
        let bistService = BistService.shared
        
        _ = await alertService.checkAlerts { symbols in
            let cryptos = await cryptoService.fetchAll24hTickers(cachePolicy: .ignoreCache)
            let stocks = await bistService.fetchStocks(forceRefresh: false)
            
            var dictionary: [String: Decimal] = [:]
            
            for c in cryptos {
                if let price = Decimal(string: c.lastPrice.replacingOccurrences(of: ",", with: ".")) {
                    dictionary[c.symbol] = price
                }
            }
            
            for s in stocks {
                if let price = Decimal(string: s.lastPrice.replacingOccurrences(of: ",", with: ".")) {
                    dictionary[s.symbol] = price
                }
            }
            return dictionary
        }
        
        // After alerts, sync the latest prices to the widget
        await syncWidgets()
    }
    
    @MainActor
    private func syncWidgets() async {
        // Sync Favorites
        let cryptoSymbols = FavoritesManager.shared.favoriteCryptoSymbols
        let stockSymbols = FavoritesManager.shared.favoriteStockSymbols
        
        // Fetch latest tickers/stocks to ensure we have data for the bridge
        let cryptos = await CryptoService.shared.fetchAll24hTickers(cachePolicy: .useCacheIfAvailable)
        let stocks = await BistService.shared.fetchStocks(forceRefresh: false)
        
        WidgetDataBridge.shared.syncFavorites(
            cryptoSymbols: cryptoSymbols,
            stockSymbols: stockSymbols,
            priceResolver: { symbol, kind in
                if kind == "crypto" {
                    let c = cryptos.first { $0.symbol == symbol }
                    let val = Double(c?.lastPrice ?? "0") ?? 0
                    let fmtPrice = val >= 1 ? String(format: "$%.2f", val) : (val >= 0.0001 ? String(format: "$%.4f", val) : "$ " + String(format: "%.8f", val))
                    return (price: fmtPrice, change: c?.priceChangePercent ?? "0%", isPositive: !(c?.priceChangePercent.contains("-") ?? false), usdPrice: val)
                } else {
                    let s = stocks.first { $0.symbol == symbol }
                    let val = Double(s?.lastPrice ?? "0") ?? 0
                    let price = "₺" + (s?.lastPrice ?? "0")
                    return (price: price, change: s?.changePercent ?? "0%", isPositive: !(s?.changePercent.contains("-") ?? false), usdPrice: val / 45.0)
                }
            }
        )
        
        // Sync Portfolio
        let assets = try? await PortfolioService.shared.getAssetsWithValue()
        let rate = await CurrencyService.shared.fetchUSDTTRYRate()
        let items = (assets ?? []).map { a -> (symbol: String, kind: String, quantity: Decimal, totalValue: Decimal) in
            (symbol: a.symbol, kind: a.kind.rawValue, quantity: a.quantity, totalValue: a.totalValueTL(rate: rate))
        }
        let total = items.reduce(Decimal(0)) { $0 + $1.totalValue }
        WidgetDataBridge.shared.syncPortfolio(assets: items, totalPortfolioValue: total)
    }
}

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isSplashing = true
    @ObservedObject private var network = NetworkMonitor.shared
    
    let alertService: AlertService
    
    var body: some View {
        ZStack(alignment: .top) {
            if isSplashing {
                SplashView(isSplashing: $isSplashing)
            } else if !hasSeenOnboarding {
                OnboardingView()
            } else {
                MainTabView()
                    .task {
                        await alertService.requestNotificationAuthorizationIfNeeded()
                        alertService.setupForegroundMonitoring(pricePublisher: PortfolioService.shared.priceUpdatePublisher)
                        alertService.syncAlertSubscriptions()
                    }
            }
            
            // Global Network Banner (Subtle top alert)
            if !network.isConnected && !isSplashing {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                    Text("İnternet bağlantınız yok")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.95))
                .shadow(radius: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .animation(.easeInOut, value: isSplashing)
    }
}
