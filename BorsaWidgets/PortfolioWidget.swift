import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let isLoggedIn: Bool
    let isBalanceHidden: Bool
    let assets: [WidgetPortfolioItem]
    let totalValue: String
}

// MARK: - Timeline Provider

struct PortfolioProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(
            date: .now,
            isLoggedIn: true,
            isBalanceHidden: false,
            assets: [
                WidgetPortfolioItem(symbol: "BTC", kind: "crypto", quantity: "0.05", totalValue: "₺45,200"),
                WidgetPortfolioItem(symbol: "THYAO", kind: "stock", quantity: "100", totalValue: "₺30,000"),
            ],
            totalValue: "₺75,200"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        let bridge = WidgetDataBridge.shared
        let assets = bridge.portfolioAssets // Already limited to top 2 by the sync logic
        completion(PortfolioEntry(
            date: .now,
            isLoggedIn: bridge.isLoggedIn,
            isBalanceHidden: bridge.isBalanceHidden,
            assets: assets,
            totalValue: bridge.totalPortfolioValue
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        let bridge = WidgetDataBridge.shared
        
        Task {
            await bridge.refreshNetworkData()
            
            let entry = PortfolioEntry(
                date: .now,
                isLoggedIn: bridge.isLoggedIn,
                isBalanceHidden: bridge.isBalanceHidden,
                assets: bridge.portfolioAssets,
                totalValue: bridge.totalPortfolioValue
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

// MARK: - Widget View

struct PortfolioWidgetView: View {
    var entry: PortfolioEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            if !entry.isLoggedIn {
                notLoggedInView
            } else if entry.assets.isEmpty {
                emptyView
            } else if family == .systemSmall {
                smallContentView
            } else {
                mediumContentView
            }
        }
        .widgetURL(URL(string: "borsaapp://portfolio"))
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.12, blue: 0.10), Color(red: 0.08, green: 0.18, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.green.opacity(0.1), .clear],
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
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("Varlıklarım")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 6)
            
            Text(entry.isBalanceHidden ? "********" : entry.totalValue)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            Spacer()
            
            if let first = entry.assets.first {
                HStack {
                    if first.kind == "crypto", let url = WidgetSharedData.logoURL(for: first.symbol),
                       let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(first.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text(first.kind == "crypto" ? "Kripto" : "BIST")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(entry.isBalanceHidden ? "***" : first.totalValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
        }
        .padding(12)
    }

    // MARK: - Medium Layout
    private var mediumContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.green.gradient)
                Text("Varlıklarım")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("Son Güncelleme: \(formattedTime)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isBalanceHidden ? "********" : entry.totalValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("Toplam Portföy Değeri")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 12)

            VStack(spacing: 8) {
                ForEach(entry.assets, id: \.symbol) { asset in
                    assetRow(asset)
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
    private func assetRow(_ asset: WidgetPortfolioItem) -> some View {
        HStack {
            // Icon / Logo
            ZStack {
                if asset.kind == "crypto", let url = WidgetSharedData.logoURL(for: asset.symbol),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(asset.kind == "crypto" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .frame(width: 26, height: 26)
                    Text(String(asset.symbol.prefix(2)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(asset.kind == "crypto" ? .cyan : .green)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(asset.symbol)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(entry.isBalanceHidden ? "***" : "\(asset.quantity) adet")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Text(entry.isBalanceHidden ? "***" : asset.totalValue)
                .font(.caption.bold())
                .foregroundColor(.green)
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
            Image(systemName: "briefcase.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.green.gradient)
            Text("Portföy Boş")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Widget Definition

struct PortfolioWidget: Widget {
    let kind = "PortfolioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortfolioProvider()) { entry in
            PortfolioWidgetView(entry: entry)
        }
        .configurationDisplayName("Varlıklarım")
        .description("Portföyünüzü ana ekrandan takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
