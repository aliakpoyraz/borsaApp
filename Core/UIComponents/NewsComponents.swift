import SwiftUI
import SafariServices

// MARK: - NewsSectionView (Yatay kaydırmalı veya dikey liste)
struct NewsSectionView: View {
    let news: [NewsItem]
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Haberler yükleniyor...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if news.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Haber bulunamadı")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    let items = Array(news.prefix(8))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NewsRowView(item: item)
                        if index < items.count - 1 {
                            Divider().padding(.leading, 82 + 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - NewsRowView
struct NewsRowView: View {
    let item: NewsItem
    @State private var showSafari = false

    var body: some View {
        Button(action: { showSafari = true }) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                thumbnailView

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.system(.caption, design: .default))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(relativeDate(item.pubDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: item.link) {
                SafariView(url: url)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let imgURL = item.imageURL, let url = URL(string: imgURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipped()
                        .cornerRadius(10)
                case .failure(_), .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
            Text(String(item.source.prefix(1)))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "az önce" }
        if diff < 3600 { return "\(Int(diff / 60)) dk önce" }
        if diff < 86400 { return "\(Int(diff / 3600)) sa önce" }
        return "\(Int(diff / 86400)) gün önce"
    }
}

// MARK: - SafariView Wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
