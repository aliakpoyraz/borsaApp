import SwiftUI
import UserNotifications

struct ProfileView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @State private var showingLogoutAlert = false
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showingLogin = false
    @State private var startWithRegister = false
    @State private var notifTestScheduled = false
    @State private var notifTestCountdown = 10
    
    // Alerts
    @State private var activeAlerts: [Alert] = []
    private let alertService = AlertService.live()

    private var currentMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Account card
                        accountCard

                        // Appearance
                        appearanceSection
                        
                        // Active Alerts
                        if authManager.isAuthenticated {
                            alertsSection
                        }

                        // About
                        aboutSection

                        // Debug + Logout
                        bottomSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Hesabım")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingLogin) { LoginView(startWithRegister: startWithRegister) }
            .alert("Çıkış Yap", isPresented: $showingLogoutAlert) {
                Button("Çıkış Yap", role: .destructive) { authManager.logOut() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Oturumunuzu kapatmak istediğinize emin misiniz?")
            }
            .task {
                loadAlerts()
            }
        }
    }

    // MARK: - Hesap Kartı (Account Card)
    private var accountCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 58, height: 58)
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            if authManager.isAuthenticated {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Giriş Yapıldı")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(authManager.userEmail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Giriş yapılmadı")
                        .font(.subheadline.weight(.semibold))
                    Text("Portföy ve favoriler için giriş yapın")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Kayıt Ol") {
                        startWithRegister = true
                        showingLogin = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.blue)

                    Button("Giriş Yap") {
                        startWithRegister = false
                        showingLogin = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Görünüm Ayarları (Appearance Section)
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "paintbrush.fill", title: "Görünüm", color: .blue)

            VStack(spacing: 0) {
                ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element) { index, mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appearanceModeRaw = mode.rawValue
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(iconColor(for: mode))
                                .frame(width: 32, height: 32)
                                .background(iconColor(for: mode).opacity(0.12))
                                .clipShape(Circle())

                            Text(mode.label)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if currentMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            } else {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < AppearanceMode.allCases.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func iconColor(for mode: AppearanceMode) -> Color {
        switch mode {
        case .system: return .blue
        case .light: return .orange
        case .dark: return .blue
        }
    }

    // MARK: - Alarmlar Bölümü (Alerts Section)
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "bell.badge.fill", title: "Aktif Alarmlarım", color: .blue)

            VStack(spacing: 0) {
                if activeAlerts.isEmpty {
                    HStack {
                        Text("Henüz kurulmuş bir alarmınız yok.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(16)
                } else {
                    ForEach(Array(activeAlerts.enumerated()), id: \.element.id) { index, alert in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(alert.symbol.contains("USDT") ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: alert.symbol.contains("USDT") ? "bitcoinsign.circle.fill" : "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16))
                                    .foregroundColor(alert.symbol.contains("USDT") ? .orange : .blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.symbol)
                                    .font(.system(size: 15, weight: .bold))
                                Text("Hedef: \(alert.isAbove ? ">" : "<") \(String(describing: alert.targetPrice))")
                                    .font(.caption)
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
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < activeAlerts.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    private func loadAlerts() {
        Task {
            let alerts = await alertService.getAlerts()
            self.activeAlerts = alerts.filter { $0.isActive }
        }
    }

    // MARK: - Hakkında Bölümü (About Section)
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "info.circle.fill", title: "Hakkında", color: .blue)

            VStack(spacing: 0) {
                infoRow(label: "Sürüm", value: "1.0.0", icon: "app.badge", color: .blue)
                Divider().padding(.leading, 62)
                infoRow(label: "Geliştirici", value: "YZL344", icon: "chevron.left.forwardslash.chevron.right", color: .blue)
                Divider().padding(.leading, 62)
                infoRow(label: "Veri Kaynağı", value: "Binance · Yahoo", icon: "antenna.radiowaves.left.and.right", color: .green)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func infoRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(label)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Alt Bölüm (Bottom Section)
    private var bottomSection: some View {
        VStack(spacing: 12) {
            // Debug reset
            Button {
                UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline)
                    Text("Tanıtım Ekranını Sıfırla")
                        .font(.subheadline)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Logout
            if authManager.isAuthenticated {
                Button {
                    showingLogoutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                        Text("Çıkış Yap")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    // MARK: - Yardımcı Fonksiyonlar (Helper)
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Bildirim Testi (Notification Test - Mantık korundu)
    @MainActor
    private func scheduleTestNotification() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings()
        if status.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔔 Fiyat Alarmı Test"
        content.body = "Hedef fiyatın üstüne çıktı! (Bu bir test bildirimidir)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "alarm.test.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await center.add(request)

        notifTestScheduled = true
        notifTestCountdown = 10
        for i in stride(from: 10, through: 1, by: -1) {
            notifTestCountdown = i
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        notifTestScheduled = false
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProfileView()
            ProfileView().preferredColorScheme(.dark)
        }
    }
}
