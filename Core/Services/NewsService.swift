import Foundation

protocol NewsServicing: Sendable {
    /// Returns mock news from Crypto & BIST.
    /// - Important: Each item will have its `sentiment` assigned by `analyzeSentiment`.
    func fetchNews() async -> [News]

    /// Basic keyword-based sentiment analysis over a title/content text.
    func analyzeSentiment(_ text: String) async -> Sentiment
}

/// Mock news service.
final class NewsService: NewsServicing, Sendable {
    private let now: @Sendable () -> Date
    private let locale: Locale
    private let positiveKeywords: [String]
    private let negativeKeywords: [String]

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        locale: Locale = Locale(identifier: "tr_TR")
    ) {
        self.now = now
        self.locale = locale
        self.positiveKeywords = [
            "rekor",
            "artis",
            "artış",
            "yukselis",
            "yükseliş",
            "boga",
            "boğa",
            "kazanc",
            "kazanç",
            "pozitif"
        ].map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: locale).lowercased(with: locale) }

        self.negativeKeywords = [
            "dusus",
            "düşüş",
            "kriz",
            "kayip",
            "kayıp",
            "satis",
            "satış",
            "negatif",
            "ayi",
            "ayı"
        ].map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: locale).lowercased(with: locale) }
    }

    func fetchNews() async -> [News] {
        let items = makeMockNews()

        var result: [News] = []
        result.reserveCapacity(items.count)

        for item in items {
            let sentiment = await analyzeSentiment("\(item.title) \(item.content)")
            result.append(
                News(
                    title: item.title,
                    content: item.content,
                    source: item.source,
                    date: item.date,
                    sentiment: sentiment
                )
            )
        }

        return result.sorted(by: { $0.date > $1.date })
    }

    func analyzeSentiment(_ text: String) async -> Sentiment {
        let normalized = normalize(text)

        let hasPositive = positiveKeywords.contains(where: { normalized.contains($0) })
        let hasNegative = negativeKeywords.contains(where: { normalized.contains($0) })

        if hasPositive, !hasNegative { return .positive }
        if hasNegative, !hasPositive { return .negative }
        return .neutral
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: locale)
            .lowercased(with: locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeMockNews() -> [(title: String, content: String, source: String, date: Date)] {
        let base = now()

        return [
            (
                title: "Bitcoin'de rekor yükseliş: Kurumsal talep artışta",
                content: "BTC tarafında hacim artışı dikkat çekiyor. Analistler boğa senaryosunu güçlendiriyor.",
                source: "Crypto Desk",
                date: base.addingTimeInterval(-20 * 60)
            ),
            (
                title: "Altcoinlerde satış baskısı: Piyasada kayıp derinleşiyor",
                content: "Bazı majör altcoinlerde düşüş hızlandı. Kısa vadede volatilite yüksek.",
                source: "Chain Pulse",
                date: base.addingTimeInterval(-55 * 60)
            ),
            (
                title: "BIST 100 gün ortasında yatay: Yatırımcılar veri bekliyor",
                content: "Endeks tarafında belirgin bir yön oluşmadı. Seans içinde sınırlı dalgalanma görüldü.",
                source: "BIST Günlük",
                date: base.addingTimeInterval(-2 * 60 * 60)
            ),
            (
                title: "Bankacılık hisselerinde artış: Pozitif bilanço beklentisi",
                content: "Sektör hisselerinde kazanç eğilimi öne çıkıyor. Piyasa beklentileri toparlanıyor.",
                source: "Piyasa Haber",
                date: base.addingTimeInterval(-3 * 60 * 60)
            ),
            (
                title: "Küresel risk iştahı zayıfladı: Kriz endişesi yeniden gündemde",
                content: "Makro tarafta belirsizlik sürüyor. Ayı senaryoları yeniden konuşuluyor.",
                source: "Makro Gündem",
                date: base.addingTimeInterval(-5 * 60 * 60)
            )
        ]
    }
}
