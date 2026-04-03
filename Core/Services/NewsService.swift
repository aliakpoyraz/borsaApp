import Foundation

// MARK: - NewsItem Model
public struct NewsItem: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let link: String
    public let pubDate: Date
    public let imageURL: String?
    public let source: String

    public init(title: String, description: String, link: String, pubDate: Date, imageURL: String?, source: String) {
        self.title = title
        self.description = description
        self.link = link
        self.pubDate = pubDate
        self.imageURL = imageURL
        self.source = source
    }
}

// MARK: - NewsService
public final class NewsService: @unchecked Sendable {
    public static let shared = NewsService()

    // Kripto haberleri için RSS kaynakları
    private let cryptoFeeds = [
        ("https://www.investing.com/rss/news_301.rss", "Investing.com"),
    ]

    // Borsa/BIST haberleri için RSS kaynakları
    private let bistFeeds = [
        ("https://www.bloomberght.com/rss", "Bloomberg HT"),
    ]

    private var cryptoCache: [NewsItem] = []
    private var bistCache: [NewsItem] = []
    private var cryptoCachedAt: Date?
    private var bistCachedAt: Date?
    private let ttl: TimeInterval = 10 * 60  // 10 dakika

    private init() {}

    // MARK: - Public API
    public func fetchCryptoNews() async -> [NewsItem] {
        if let cached = cryptoCachedAt, Date().timeIntervalSince(cached) < ttl, !cryptoCache.isEmpty {
            return cryptoCache
        }
        let items = await fetchFeeds(cryptoFeeds)
        cryptoCache = items
        cryptoCachedAt = Date()
        return items
    }

    // BIST ile ilgili haber filtresi — borsa, hisse, piyasa, ekonomi, TL, TCMB, enflasyon vs.
    private let bistKeywords = [
        "borsa", "hisse", "bist", "xist", "xu100", "piyasa", "tcmb", "faiz", "enflasyon",
        "spk", "ekonomi", "yabancı yatırım", "döviz", "dolar", "euro", "hazine", "kbsm",
        "bankac", "şirket", "ihraç", "tahvil", "emtia", "altin", "altın", "petrol",
        "büyüme", "ihracat", "ithalat", "gsyh", "cari açık", "merkez bank",
        "yatırım", "fon", "portföy", "temettü", "bono", "kredi", "aracı kurum"
    ]

    public func fetchBistNews() async -> [NewsItem] {
        if let cached = bistCachedAt, Date().timeIntervalSince(cached) < ttl, !bistCache.isEmpty {
            return bistCache
        }
        let items = await fetchFeeds(bistFeeds)
        // Filter only finance/economy-related news
        let filtered = items.filter { item in
            let combined = (item.title + " " + item.description).lowercased()
            return bistKeywords.contains(where: { combined.contains($0) })
        }
        let result = filtered.isEmpty ? Array(items.prefix(10)) : filtered
        bistCache = result
        bistCachedAt = Date()
        return result
    }

    // MARK: - RSS Parsing
    private func fetchFeeds(_ feeds: [(String, String)]) async -> [NewsItem] {
        var allItems: [NewsItem] = []

        await withTaskGroup(of: [NewsItem].self) { group in
            for (urlStr, source) in feeds {
                group.addTask {
                    return await self.fetchSingleFeed(urlStr: urlStr, source: source)
                }
            }
            for await items in group {
                allItems.append(contentsOf: items)
            }
        }

        return allItems.sorted { $0.pubDate > $1.pubDate }
    }

    private func fetchSingleFeed(urlStr: String, source: String) async -> [NewsItem] {
        guard let url = URL(string: urlStr) else { return [] }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, _) = try await URLSession.shared.data(for: request)
            return parseRSS(data: data, source: source)
        } catch {
            print("News fetch error (\(source)): \(error.localizedDescription)")
            return []
        }
    }

    private func parseRSS(data: Data, source: String) -> [NewsItem] {
        let parser = RSSParser(source: source)
        return parser.parse(data: data)
    }
}

// MARK: - Simple RSS XML Parser
final class RSSParser: NSObject, XMLParserDelegate {
    private let source: String
    private var items: [NewsItem] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentDescription = ""
    private var currentImageURL: String?
    private var insideItem = false
    private var currentCDATA = ""

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    private let altDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    init(source: String) {
        self.source = source
    }

    func parse(data: Data) -> [NewsItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentCDATA = ""

        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentDescription = ""
            currentImageURL = nil
        }

        if insideItem, elementName == "enclosure", let url = attributeDict["url"] {
            currentImageURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideItem {
            currentCDATA += string
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if insideItem, let str = String(data: CDATABlock, encoding: .utf8) {
            currentCDATA += str
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentCDATA.trimmingCharacters(in: .whitespacesAndNewlines)

        if insideItem {
            switch elementName {
            case "title": currentTitle = text
            case "link": if currentLink.isEmpty { currentLink = text }
            case "pubDate": currentPubDate = text
            case "description":
                if currentDescription.isEmpty {
                    currentDescription = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case "image":
                if currentImageURL == nil && text.hasPrefix("http") {
                    currentImageURL = text
                }
            case "item":
                if !currentTitle.isEmpty && !currentLink.isEmpty {
                    let pubDate = dateFormatter.date(from: currentPubDate)
                        ?? altDateFormatter.date(from: currentPubDate)
                        ?? Date()

                    let item = NewsItem(
                        title: currentTitle,
                        description: currentDescription,
                        link: currentLink,
                        pubDate: pubDate,
                        imageURL: currentImageURL,
                        source: source
                    )
                    items.append(item)
                }
                insideItem = false
            default: break
            }
        }
        currentCDATA = ""
    }
}
