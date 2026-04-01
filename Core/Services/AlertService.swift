import Foundation
import UserNotifications

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

    /// Compare current prices with saved alerts and trigger a local notification if target reached.
    /// - Note: This method deactivates triggered alerts to prevent repeated notifications.
    @discardableResult
    func checkAlerts(currentPrices: [String: Decimal]) async -> [Alert]

    /// Convenience overload to fetch prices from an external market service/provider.
    @discardableResult
    func checkAlerts(
        priceProvider: @Sendable (_ symbols: [String]) async throws -> [String: Decimal]
    ) async -> [Alert]
}

public actor AlertService: AlertServicing {
    // MARK: - Dependencies
    private let defaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let now: @Sendable () -> Date

    // MARK: - Storage
    private let alertsKey = "alerts.items.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Init
    public init(
        defaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.now = now
    }

    // MARK: - API

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
    }

    public func removeAlert(id: UUID) async {
        var alerts = loadAlerts()
        alerts.removeAll(where: { $0.id == id })
        storeAlerts(alerts)
    }

    public func setAlertActive(id: UUID, isActive: Bool) async {
        var alerts = loadAlerts()
        guard let idx = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[idx].isActive = isActive
        storeAlerts(alerts)
    }

    public func removeAllAlerts() async {
        defaults.removeObject(forKey: alertsKey)
    }

    @discardableResult
    public func checkAlerts(currentPrices: [String: Decimal]) async -> [Alert] {
        var alerts = loadAlerts()
        var triggered: [Alert] = []

        // Normalize incoming prices for symbol matching
        let normalizedPrices: [String: Decimal] = Dictionary(
            uniqueKeysWithValues: currentPrices.map { (normalize($0.key), $0.value) }
        )

        for i in alerts.indices {
            guard alerts[i].isActive else { continue }
            let symbol = normalize(alerts[i].symbol)
            guard let current = normalizedPrices[symbol] else { continue }

            if shouldTrigger(alert: alerts[i], currentPrice: current) {
                await triggerNotification(alert: alerts[i], currentPrice: current)
                alerts[i].isActive = false
                triggered.append(alerts[i])
            }
        }

        if !triggered.isEmpty {
            storeAlerts(alerts)
        }

        return triggered
    }

    @discardableResult
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

    // MARK: - Internals

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
        // Try to ensure auth is requested at least once.
        await requestNotificationAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Fiyat Alarmı"
        content.body = notificationBody(alert: alert, currentPrice: currentPrice)
        content.sound = .default

        // Add minimal metadata for deep-link / debug if needed.
        content.userInfo = [
            "alertId": alert.id.uuidString,
            "symbol": normalize(alert.symbol),
            "targetPrice": "\(alert.targetPrice)",
            "currentPrice": "\(currentPrice)",
            "isAbove": alert.isAbove,
            "firedAt": now().timeIntervalSince1970
        ]

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
}
