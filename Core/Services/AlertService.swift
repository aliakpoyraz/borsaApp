import Foundation
import UIKit
import UserNotifications
import Combine

public struct Alert: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var symbol: String
    public var targetPrice: Decimal
    /// true: fiyat hedefin üstüne çıkınca tetikle, false: hedefin altına inince tetikle
    public var isAbove: Bool
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        symbol: String,
        targetPrice: Decimal,
        isAbove: Bool,
        isActive: Bool = true
    ) {
        self.id = id
        self.symbol = symbol
        self.targetPrice = targetPrice
        self.isAbove = isAbove
        self.isActive = isActive
    }
}

public protocol AlertServicing: Sendable {
    func requestNotificationAuthorizationIfNeeded() async

    func getAlerts() async -> [Alert]
    func upsert(_ alert: Alert) async
    func removeAlert(id: UUID) async
    func setAlertActive(id: UUID, isActive: Bool) async
    func removeAllAlerts() async

    /// Mevcut fiyatları kayıtlı alarmlarla karşılaştırır ve hedef fiyata ulaşıldığında yerel bildirim tetikler.
    /// - Not: Bu yöntem, mükerrer bildirimleri önlemek için tetiklenen alarmları devre dışı bırakır.
    @discardableResult
    func checkAlerts(currentPrices: [String: Decimal]) async -> [Alert]

    /// Harici bir piyasa servisi/sağlayıcısından fiyatları çekmek için kolaylık sağlayan metot.
    @discardableResult
    func checkAlerts(
        priceProvider: @Sendable (_ symbols: [String]) async throws -> [String: Decimal]
    ) async -> [Alert]

    /// Uygulama ön plandayken alarmları gerçek zamanlı tetiklemek için bir fiyat yayıncısını (publisher) gözlemlemeye başlar.
    func setupForegroundMonitoring(
        pricePublisher: AnyPublisher<(symbol: String, price: Decimal, percent: Decimal?), Never>
    )
    
    func syncAlertSubscriptions()
}

@MainActor
public final class AlertService: NSObject, AlertServicing, UNUserNotificationCenterDelegate, @unchecked Sendable {
    // MARK: - Bağımlılıklar
    private let defaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let now: @Sendable () -> Date

    // MARK: - Depolama
    private let alertsKey = "alerts.items.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()
    private var monitoringCancellable: AnyCancellable?

    // MARK: - Başlatıcı
    public init(
        defaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.now = now
        super.init()
        self.notificationCenter.delegate = self
    }

    /// Swift 6'da .current() kullanımını main-actor güvenli tutmak için yardımcı fabrika metodu.
    @MainActor
    public static func live(
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> AlertService {
        AlertService(defaults: defaults, notificationCenter: .current(), now: now)
    }

    // MARK: - API Metotları

    public func requestNotificationAuthorizationIfNeeded() async {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .denied:
            return
        case .notDetermined:
            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return
        }
    }

    public func getAlerts() async -> [Alert] {
        loadAlerts()
    }

    public func upsert(_ alert: Alert) async {
        var alerts = loadAlerts()
        let normalized = normalize(alert.symbol)

        if let idx = alerts.firstIndex(where: { $0.id == alert.id }) {
            var updated = alert
            updated.symbol = normalized
            alerts[idx] = updated
        } else {
            var newAlert = alert
            newAlert.symbol = normalized
            alerts.append(newAlert)
        }

        storeAlerts(alerts)
        syncAlertSubscriptions()
    }

    public func removeAlert(id: UUID) async {
        var alerts = loadAlerts()
        alerts.removeAll(where: { $0.id == id })
        storeAlerts(alerts)
        syncAlertSubscriptions()
    }

    public func setAlertActive(id: UUID, isActive: Bool) async {
        var alerts = loadAlerts()
        guard let idx = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[idx].isActive = isActive
        storeAlerts(alerts)
        syncAlertSubscriptions()
    }

    public func removeAllAlerts() async {
        defaults.removeObject(forKey: alertsKey)
    }

    @discardableResult
    public func checkAlerts(currentPrices: [String: Decimal]) async -> [Alert] {
        var alerts = loadAlerts()
        var triggered: [Alert] = []

        // Sembol eşleşmesi için gelen fiyatları normalize et
        let normalizedPrices: [String: Decimal] = Dictionary(
            uniqueKeysWithValues: currentPrices.map { (normalize($0.key), $0.value) }
        )
        
        var alertsToTrigger: [Alert] = []

        for i in alerts.indices {
            guard alerts[i].isActive else { continue }
            let symbol = normalize(alerts[i].symbol)
            guard let current = normalizedPrices[symbol] else { continue }

            if shouldTrigger(alert: alerts[i], currentPrice: current) {
                alertsToTrigger.append(alerts[i])
                alerts[i].isActive = false
                triggered.append(alerts[i])
            }
        }

        // Eşzamanlı (concurrent) girişleri önlemek için asenkron işlemden hemen önce kaydet
        if !triggered.isEmpty {
            storeAlerts(alerts)
        }
        
        // Şimdi bildirimleri asenkron olarak tetikle
        for alert in alertsToTrigger {
            let symbol = normalize(alert.symbol)
            guard let currentPrice = normalizedPrices[symbol] else { continue }
            await triggerNotification(alert: alert, currentPrice: currentPrice)
        }

        return triggered
    }

    public func checkAlerts(
        priceProvider: @Sendable (_ symbols: [String]) async throws -> [String: Decimal]
    ) async -> [Alert] {
        let symbols = Array(Set(loadAlerts().map { normalize($0.symbol) }))
        guard !symbols.isEmpty else { return [] }

        let prices: [String: Decimal]
        do {
            prices = try await priceProvider(symbols)
        } catch {
            return []
        }

        return await checkAlerts(currentPrices: prices)
    }

    public func setupForegroundMonitoring(
        pricePublisher: AnyPublisher<(symbol: String, price: Decimal, percent: Decimal?), Never>
    ) {
        monitoringCancellable = pricePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }
                Task {
                    await self.checkAlerts(currentPrices: [update.symbol: update.price])
                }
            }
    }
    
    public func syncAlertSubscriptions() {
        let alerts = loadAlerts()
        let activeSymbols = alerts.filter { $0.isActive }.map { normalize($0.symbol) }
        guard !activeSymbols.isEmpty else { return }
        
        let cryptoSymbols = activeSymbols.map { s -> String in
            if !s.hasSuffix("USDT") && !s.hasSuffix("TRY") && !s.hasSuffix("BUSD") {
                return s + "USDT"
            }
            return s
        }
        
        Task {
            await PortfolioService.shared.subscribeCryptoLivePrices(symbols: cryptoSymbols)
        }
    }

    // MARK: - Dahili Yardımcı Metotlar

    private func loadAlerts() -> [Alert] {
        guard let data = defaults.data(forKey: alertsKey) else { return [] }
        return (try? decoder.decode([Alert].self, from: data)) ?? []
    }

    private func storeAlerts(_ alerts: [Alert]) {
        if let data = try? encoder.encode(alerts) {
            defaults.set(data, forKey: alertsKey)
        }
    }

    private func normalize(_ symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func shouldTrigger(alert: Alert, currentPrice: Decimal) -> Bool {
        if alert.isAbove {
            return currentPrice >= alert.targetPrice
        } else {
            return currentPrice <= alert.targetPrice
        }
    }

    private func triggerNotification(alert: Alert, currentPrice: Decimal) async {
        // Yetkinin en az bir kez istendiğinden emin olmaya çalış.
        await requestNotificationAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Fiyat Alarmı"
        content.body = notificationBody(alert: alert, currentPrice: currentPrice)
        content.sound = .default

        // Gerekirse derin bağlantı (deep-link) veya hata ayıklama için minimal meta verileri ekle.
        content.userInfo = [
            "alertId": alert.id.uuidString,
            "symbol": normalize(alert.symbol),
            "targetPrice": "\(alert.targetPrice)",
            "currentPrice": "\(currentPrice)",
            "isAbove": alert.isAbove,
            "firedAt": now().timeIntervalSince1970
        ]
        
        if let attachment = await createAssetLogoAttachment(symbol: alert.symbol) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "alert.\(alert.id.uuidString)",
            content: content,
            trigger: nil // fire immediately
        )

        try? await notificationCenter.add(request)
    }

    private func notificationBody(alert: Alert, currentPrice: Decimal) -> String {
        let direction = alert.isAbove ? "üstüne çıktı" : "altına indi"
        return "\(normalize(alert.symbol)) hedefi: \(alert.targetPrice) — mevcut: \(currentPrice). Fiyat hedefin \(direction)."
    }

    private func createAssetLogoAttachment(symbol: String) async -> UNNotificationAttachment? {
        let cleanSymbol = symbol.replacingOccurrences(of: "USDT", with: "").lowercased()
        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent("PushIcons")
        let fileURL = folderURL.appendingPathComponent("\(cleanSymbol).png")
        let fallbackURL = folderURL.appendingPathComponent("AppLogo.png")
        
        let mirrorURLs = [
            URL(string: "https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/\(cleanSymbol).png"),
            URL(string: "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(cleanSymbol).png"),
            URL(string: "https://assets.coincap.io/assets/icons/\(cleanSymbol)@2x.png")
        ].compactMap { $0 }
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            
            for url in mirrorURLs {
                if let (data, response) = try? await URLSession.shared.data(from: url),
                   let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    try data.write(to: fileURL)
                    return try UNNotificationAttachment(identifier: cleanSymbol, url: fileURL, options: nil)
                }
            }
            
            guard let image = UIImage(named: "AppLogo"),
                  let data = image.pngData() else {
                return nil
            }
            
            try data.write(to: fallbackURL)
            return try UNNotificationAttachment(identifier: "AppLogo", url: fallbackURL, options: nil)
        } catch {
            return nil
        }
    }

    // MARK: - Bildirim Merkezi Delegesi (UNUserNotificationCenterDelegate)

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Uygulama ön plandayken bile başlığı göster ve ses çal
        completionHandler([.banner, .sound, .list])
    }
}
