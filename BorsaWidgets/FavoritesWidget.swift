import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let isLoggedIn: Bool
    let items: [WidgetFavoriteItem]
}

// MARK: - Timeline Provider

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        FavoritesEntry(date: .now, isLoggedIn: true, items: [
            WidgetFavoriteItem(symbol: "BTC", kind: "crypto", price: "$67,200", change: "+2.4%", isPositive: true),
            WidgetFavoriteItem(symbol: "THYAO", kind: "stock", price: "₺300", change: "-1.2%", isPositive: false),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        let bridge = WidgetDataBridge.shared
        completion(FavoritesEntry(
            date: .now,
            isLoggedIn: bridge.isLoggedIn,
            items: bridge.topFavorites
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        let bridge = WidgetDataBridge.shared
        
        Task {
            await bridge.refreshNetworkData()
            
            let entry = FavoritesEntry(
                date: .now,
                isLoggedIn: bridge.isLoggedIn,
                items: bridge.topFavorites
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

// MARK: - Widget View

struct FavoritesWidgetView: View {
    var entry: FavoritesEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            if !entry.isLoggedIn {
                notLoggedInView
            } else if entry.items.isEmpty {
                emptyView
            } else if family == .systemSmall {
                smallContentView
            } else {
                mediumContentView
            }
        }
        .widgetURL(URL(string: "borsaapp://favorites"))
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.10, blue: 0.18), Color(red: 0.12, green: 0.15, blue: 0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.blue.opacity(0.1), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 100
                )
            }
        }
    }

    // MARK: - Small Layout
    private var smallContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                Text("Favoriler")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                ForEach(entry.items.prefix(2), id: \.symbol) { item in
                    smallFavoriteRow(item)
                }
            }
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private func smallFavoriteRow(_ item: WidgetFavoriteItem) -> some View {
        HStack {
            // Mini Icon
            if item.kind == "crypto", let url = WidgetSharedData.logoURL(for: item.symbol),
               let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(item.price)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text(item.change)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(item.isPositive ? .green : .red)
        }
        .padding(6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(6)
    }

    // MARK: - Medium Layout
    private var mediumContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.yellow.gradient)
                Text("Favorilerim")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("Son Güncelleme: \(formattedTime)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 12)

            VStack(spacing: 8) {
                ForEach(entry.items.prefix(3), id: \.symbol) { item in
                    favoriteRow(item)
                }
            }
        }
        .padding(14)
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.date)
    }

    @ViewBuilder
    private func favoriteRow(_ item: WidgetFavoriteItem) -> some View {
        HStack {
            // Icon / Logo
            ZStack {
                if item.kind == "crypto", let url = WidgetSharedData.logoURL(for: item.symbol),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(item.kind == "crypto" ? Color.blue.opacity(0.2) : Color.indigo.opacity(0.2))
                        .frame(width: 26, height: 26)
                    Text(String(item.symbol.prefix(2)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(item.kind == "crypto" ? .cyan : .indigo)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.symbol)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(item.kind == "crypto" ? "Kripto" : "BIST")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(item.price)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(item.change)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(item.isPositive ? .green : .red)
            }
        }
    }

    private var notLoggedInView: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.5))
            Text("Giriş Yapın")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow.gradient)
            Text("Favori Yok")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Widget Definition

struct FavoritesWidget: Widget {
    let kind = "FavoritesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            FavoritesWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorilerim")
        .description("Favori hisse ve kripto varlıklarınızı takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
