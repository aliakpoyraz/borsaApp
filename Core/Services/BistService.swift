import Foundation

public protocol BistServicing: Sendable {
    func fetchStocks(forceRefresh: Bool) async -> [Stock]
    func searchStocks(query: String) async -> [Stock]
    func fetchHistoricalPrices(symbol: String, period: String) async throws -> [Double]
}

// MARK: - BistService
// Uses Yahoo Finance with proper iOS-like headers that bypass the 429 rate limiting browser block.
// Falls back to cached or static data if fetching fails.
public final class BistService: BistServicing, @unchecked Sendable {
    private let ttl: TimeInterval = 15 * 60
    private let now: @Sendable () -> Date

    private var cachedAt: Date?
    private var cachedStocks: [Stock]?
    
    public static let shared = BistService()

    // All major BIST stocks — used for search and as fallback
    private let knownStocks: [(symbol: String, name: String)] = [
        // BIST 30 / Büyük Şirketler
        ("THYAO", "Türk Hava Yolları"),
        ("ASELS", "Aselsan"),
        ("EREGL", "Ereğli Demir Çelik"),
        ("KCHOL", "Koç Holding"),
        ("GARAN", "Garanti BBVA"),
        ("SAHOL", "Sabancı Holding"),
        ("TUPRS", "Tüpraş"),
        ("BIMAS", "BİM Mağazalar"),
        ("AKBNK", "Akbank"),
        ("ISCTR", "İş Bankası C"),
        ("SISE",  "Şişe Cam"),
        ("YKBNK", "Yapı Kredi Bankası"),
        ("PGSUS", "Pegasus Hava Taşımacılığı"),
        ("VAKBN", "Vakıflar Bankası"),
        ("HALKB", "Halkbank"),
        ("EKGYO", "Emlak Konut GYO"),
        ("PETKM", "Petkim Petrokimya"),
        ("ARCLK", "Arçelik"),
        ("TCELL", "Turkcell"),
        ("TOASO", "Tofaş Oto Fabrikası"),
        ("FROTO", "Ford Otomotiv"),
        ("TTKOM", "Türk Telekomünikasyon"),
        ("KOZAL", "Koza Altın"),
        ("ENKAI", "Enka İnşaat"),
        ("MGROS", "Migros Ticaret"),
        ("DOHOL", "Doğan Holding"),
        ("TAVHL", "TAV Havalimanı Holding"),
        ("CCOLA", "Coca-Cola İçecek"),
        ("SODA",  "Soda Sanayii"),
        ("OYAKC", "Oyak Çimento"),
        // Bankacılık
        ("QNBFB", "QNB Finansbank"),
        ("ENPAM", "Enpam"),
        ("TSKB",  "Türkiye Sınai Kalkınma Bankası"),
        ("ALBRK", "Albaraka Türk"),
        ("ICBCT", "ICBC Turkey Bank"),
        ("KLNMA", "Türkiye Kalkınma Bankası"),
        ("ZRGYO", "Ziraat GYO"),
        ("ISBTR", "İş Bankası TR"),
        ("DENIZ", "Denizbank"),
        // Holding & Yatırım
        ("AGHOL", "AG Anadolu Grubu Holding"),
        ("ALARK", "Alarko Holding"),
        ("AEFES", "Anadolu Efes Biracılık"),
        ("BERA",  "Bera Holding"),
        ("BMEKS", "Bimeks Bilgi İşlem"),
        ("BRYAT", "Borusan Birleşik"),
        ("CEMAS", "Çemaş Döküm Sanayi"),
        ("DEVA",  "Deva Holding"),
        ("DITAS", "Ditaş Doğan"),
        ("DNISI", "Doğan Şirketler Grubu"),
        ("ECZYT", "Eczacıbaşı Yatırım"),
        ("EGEEN", "Ege Gübre"),
        ("EGPRO", "EG Profesyonel Hizmetler"),
        ("EMKEL", "Emkel Elektrik"),
        ("EPLAS", "Egeplast"),
        ("ESCOM", "Escort Teknoloji"),
        ("GESAN", "Gesan"),
        ("GLBMD", "Global MD"),
        ("GSDHO", "GSD Holding"),
        ("GUBRF", "Gübre Fabrikaları"),
        ("HUNER", "Hünkar"),
        ("IHEVA", "İhlas Ev Aletleri"),
        ("IHLGM", "İhlas Gazetecilik"),
        ("IHLAS", "İhlas Holding"),
        ("INDES", "İndeks Bilgisayar"),
        ("ISSEN", "İş Yatırım Menkul Değerler"),
        ("ITTFH", "İttifak Holding"),
        ("JANTS", "Jantsa Jant Sanayi"),
        ("KARSN", "Karsan Otomotiv"),
        ("KATMR", "Katmerciler"),
        ("KCAER", "Koç Allianz Sigorta"),
        ("KONTR", "Kontrolmatik Teknoloji"),
        ("KONYA", "Konya Çimento"),
        ("KORDS", "Kordsa"),
        ("KOZAA", "Koza Madencilik-A"),
        ("KRDMD", "Kardemir D"),
        ("KRONT", "Krontek"),
        // Sanayi & Üretim
        ("BRSAN", "Borusan Mannesmann"),
        ("CIMSA", "Çimsa Çimento"),
        ("ADANA", "Adana Çimento A"),
        ("ADNAC", "Adana Çimento C"),
        ("AFYON", "Afyon Çimento"),
        ("AKENR", "Ak Enerji"),
        ("AKCNS", "Akçansa Çimento"),
        ("AKSEN", "Aksa Enerji"),
        ("ALKIM", "Alkim Alkali Kimya"),
        ("ANACM", "Anadolu Cam"),
        ("ANEN",  "Anemon Otel"),
        ("ASUZU", "Anadolu Isuzu"),
        ("BAGFS", "Bagfaş Bandırma Gübre"),
        ("BAKAB", "Bak Ambalaj"),
        ("BANVT", "Bandırma Vitaminli"),
        ("BFREN", "Bosch Fren"),
        ("BIOEN", "BioEnfra"),
        ("BIZIM", "Bizim Toptan"),
        ("BLCYT", "BiLiCim Teknoloji"),
        ("BMELK", "Birlik Mensucat"),
        ("BNTAS", "Bantaş"),
        ("BOBET", "Bobet"),
        ("BORLS", "Borçelik"),
        ("BOSSA", "Bossa Ticaret"),
        ("BUCIM", "Bursa Çimento"),
        ("BURCE", "Burçelik"),
        ("BURVA", "Bursa Yatırım"),
        ("BVSAN", "Burçelik Vana"),
        ("CARFA", "CarrefourSA"),
        ("CMBTN", "Çimbeton"),
        ("DAGI",  "Dagi Giyim"),
        ("DARDL", "Dardanel Gıda"),
        ("DENGE", "Denge Yatırım"),
        ("DGKLB", "Doğanlar Mobilya"),
        ("DIRIT", "Diriteks"),
        ("DMSAS", "Demisaş Döküm"),
        ("DNZGM", "Deniz GYO"),
        ("DOAS",  "Doğuş Otomotiv"),
        ("DOBUR", "Dobur"),
        ("DOKTA", "Döktaş Dökümcülük"),
        ("DURDO", "Dürder"),
        ("DYOBY", "DYO Boya"),
        ("EBEBK", "Ebebek"),
        ("ECILC", "Eczacıbaşı İlaç"),
        ("EDIP",  "Edip Gayrimenkul"),
        ("EGGUB", "Ege Gübre"),
        ("EGPWR", "EG Power"),
        ("EKSUN", "Eksun Gıda"),
        ("ELITE", "Elit Tarım"),
        ("EMNIS", "Emniyet Gıda"),
        ("ENJSA", "Enerjisa Enerji"),
        ("EPLAS", "Egeplast"),
        // Teknoloji & Yazılım
        ("LOGO",  "Logo Yazılım"),
        ("NETAS", "Netaş Telekomünikasyon"),
        ("ARENA", "Arena Bilgisayar"),
        ("ARMDA", "Armada Bilgisayar"),
        ("ASBIT", "AS Biliş"),
        ("ESCOM", "Escort Teknoloji"),
        ("FONET", "Fonet Bilgi Teknolojileri"),
        ("INDES", "İndeks Bilgisayar"),
        ("KFEIN", "Kafein Yazılım"),
        ("LINK",  "Link Bilgisayar"),
        ("MAVI",  "Mavi Giyim"),
        ("MERIT", "Merit Turizm"),
        ("NETPA", "Net Turizm"),
        ("NUHCM", "Nuh Çimento"),
        ("NUGYO", "Nurol GYO"),
        ("OFSYM", "Özyazıcı"),
        ("ONCSM", "Onur Su"),
        ("ORCAY", "Orçay Ortaklık"),
        ("ORGE",  "Orge Elektrik"),
        ("OSMEN", "Osmaniye Enerji"),
        ("OSTIM", "Ostim Endüstriyel"),
        ("OTKAR", "Otokar"),
        ("OYAYO", "Oyak Yatırım"),
        ("OYLUM", "Oylum Sınai"),
        ("OZGYO", "Özderici GYO"),
        ("OZKGY", "Özak GYO"),
        ("PAPIL", "Paperwork"),
        ("PAREG", "Pare Girişim"),
        ("PARSN", "Parsan"),
        ("PASEU", "Pasha Fintech"),
        ("PDSTU", "Pınar Damızlık"),
        ("PENGD", "Penguen Gıda"),
        ("PETUN", "Pınar ETUN"),
        ("PINSU", "Pınar Su"),
        ("PKART", "Plastikart"),
        ("PKENT", "Petrokent"),
        ("PNSUT", "Pınar Süt"),
        ("POLHO", "Polisan Holding"),
        ("PRKAB", "Türk Prysmian Kablo"),
        ("PRKME", "Park Elektrik"),
        ("PRZMA", "Prizmatik"),
        ("PSDTC", "PSD Teknik"),
        // Perakende
        ("SOKM",  "Şok Marketler"),
        ("MPARK", "MLP Sağlık"),
        ("BANVT", "Bandırma Vitamin"),
        ("ULAS",  "Ulaştırma"),
        ("SMART", "Smart Güneş"),
        // Enerji & Madencilik
        ("AKENR", "Ak Enerji"),
        ("AKSEN", "Aksa Enerji"),
        ("ENJSA", "Enerjisa"),
        ("ZOREN", "Zorlu Enerji"),
        ("TUREX", "Türkerler Enerji"),
        ("IPEKE", "İpek Doğal Enerji"),
        ("ODAS",  "Odaş Elektrik"),
        ("METUR", "Metura Enerji"),
        ("DEMIR", "Demir Çelik"),
        ("ISDMR", "İskenderun Demir Çelik"),
        // GYO
        ("ISGYO", "İş GYO"),
        ("HLGYO", "Halk GYO"),
        ("VRGYO", "Varlık GYO"),
        ("OZKGY", "Özak GYO"),
        ("ALGYO", "Alarko GYO"),
        ("SNGYO", "Sinpaş GYO"),
        ("TRGYO", "Torunlar GYO"),
        ("YGGYO", "Yeşil GYO"),
        // Ulaştırma & Lojistik
        ("CLEBI", "Çelebi Hava"),
        ("UCAK",  "Uçak Servisi"),
        ("APORT", "Airportu"),
        ("SDTTR", "SDT Uzay ve Savunma"),
        // Sigorta & Finans
        ("AKGRT", "Aksigorta"),
        ("ANHYT", "Anadolu Hayat Emeklilik"),
        ("AVHOL", "AV Holding"),
        ("RAYSG", "Ray Sigorta"),
        ("TURSG", "Türk Sigorta"),
        // Diğer
        ("SUMAS", "Sumaş"),
        ("HATEK", "Hateks"),
        ("SERVE", "Serve"),
        ("SELEC", "Selec"),
        ("SEYKM", "Seyidoğlu Kimya"),
        ("SILVR", "Silverline"),
        ("SKBNK", "Şekerbank"),
        ("SKYMD", "Sky Medya"),
        ("SMRTG", "Smart Güneş"),
        ("SNPAM", "Sanpaş"),
        ("SRVGY", "Servet GYO"),
        ("SUWEN", "Süwen"),
        ("TACTR", "Tacturk"),
        ("TATGD", "Tat Gıda"),
        ("TCELL", "Turkcell"),
        ("TDGYO", "Trend GYO"),
        ("TEBNK", "TEB"),
        ("TEKTU", "Tek-Art Turizm"),
        ("TEZOL", "Tezol"),
        ("TKFEN", "Tekfen Holding"),
        ("TKNSA", "Teknosa"),
        ("TLMAN", "Tallim"),
        ("TMPOL", "Temapol"),
        ("TRCAS", "Turcas Petrol"),
        ("TRILC", "Trilc"),
        ("TSGYO", "Toros Tarım GYO"),
        ("TTRAK", "Türk Traktör"),
        ("TUCLK", "Tucalık"),
        ("TUKAS", "Tukas Gıda"),
        ("TURGG", "Türkiye İş"),
        ("TURVZ", "Turvazon"),
        ("UCAK",  "Uçak Servisi"),
        ("ULUUN", "Ulusal Un"),
        ("USAK",  "Uşak Seramik"),
        ("USEGS", "US Enerji"),
        ("UTPYA", "Utopya"),
        ("UZERB", "Üzerboyu"),
        ("VAKKO", "Vakko Tekstil"),
        ("VBTYZ", "VBT Yazılım"),
        ("VERTU", "Vertu"),
        ("VESBE", "Vestel Beyaz Eşya"),
        ("VESTL", "Vestel Elektronik"),
        ("VKING", "Viking Kağıt"),
        ("VKFYO", "Vakıf Finansal Kiralama YO"),
        ("VKGYO", "Vakıf GYO"),
        ("YKGYO", "Yapı Kredi Koray GYO"),
        ("YUNSA", "Yünsa"),
        ("ZOREN", "Zorlu Enerji"),
    ]

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: - Fetch Stocks
    public func fetchStocks(forceRefresh: Bool = false) async -> [Stock] {
        if !forceRefresh, let cachedAt, let cachedStocks, now().timeIntervalSince(cachedAt) <= ttl {
            return cachedStocks
        }

        // Fetch top 30 major stocks for the dashboard
        let symbols = Array(knownStocks.prefix(30).map { $0.symbol })
        var live = await fetchYahooQuotes(symbols: symbols)

        if live.isEmpty {
            print("BistService: Yahoo batch failed, using per-symbol fallback...")
            live = await fetchFallbackQuotes(symbols: symbols)
        }

        if !live.isEmpty {
            cachedAt = now()
            cachedStocks = live
            return live
        }

        // Return cached or placeholder if API fails
        if let cached = cachedStocks { return cached }
        return knownStocks.prefix(30).map {
            Stock(symbol: $0.symbol, description: $0.name, lastPrice: "—", changePercent: "—", volume: "—")
        }
    }

    // MARK: - Search Stocks
    public func searchStocks(query: String) async -> [Stock] {
        guard !query.isEmpty else { return [] }
        let q = query.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter known stocks list (symbol prefix OR name contains query)
        let matched = knownStocks.filter {
            $0.symbol.hasPrefix(q) || $0.symbol.contains(q) || $0.name.localizedCaseInsensitiveContains(query)
        }
        
        var results: [Stock] = []
        
        if !matched.isEmpty {
            // Fetch live prices for matched symbols (up to 12 for performance)
            let limitedMatches = Array(matched.prefix(12))
            
            await withTaskGroup(of: Stock?.self) { group in
                for match in limitedMatches {
                    group.addTask {
                        await self.fetchSingleQuote(symbol: match.symbol)
                    }
                }
                
                for await stock in group {
                    if let s = stock {
                        results.append(s)
                    }
                }
            }
            
            // Fill in placeholders for those that couldn't be fetched live
            let fetchedSymbols = Set(results.map { $0.symbol })
            for match in limitedMatches {
                if !fetchedSymbols.contains(match.symbol) {
                    results.append(Stock(
                        symbol: match.symbol,
                        description: match.name,
                        lastPrice: "—",
                        changePercent: "—",
                        volume: "—"
                    ))
                }
            }
            
            return results.sorted { $0.symbol < $1.symbol }
        }
        
        // Not in knownStocks — try to fetch directly from Yahoo by symbol
        if q.count >= 3 {
            if let directStock = await fetchSingleQuote(symbol: q) {
                return [directStock]
            }
        }
        
        return []
    }

    // MARK: - Yahoo Finance quote fetcher - with staggered fallback sources
    private func fetchYahooQuotes(symbols: [String]) async -> [Stock] {
        // Source 1: Yahoo query1 with crumbs approach (most reliable for BIST)
        let symbolsIS = symbols.map { "\($0).IS" }.joined(separator: ",")
        
        // Try three different Yahoo endpoints
        let fields = "&fields=marketCap,trailingPE,forwardPE,priceToBook,trailingAnnualDividendYield,dividendYield,regularMarketPrice,regularMarketChangePercent,regularMarketDayHigh,regularMarketDayLow,regularMarketVolume"
        let endpoints = [
            "https://query1.finance.yahoo.com/v8/finance/quote?symbols=\(symbolsIS)&formatted=false&lang=tr-TR&region=TR\(fields)",
            "https://query2.finance.yahoo.com/v8/finance/quote?symbols=\(symbolsIS)&formatted=false\(fields)",
            "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbolsIS)\(fields)"
        ]

        for urlStr in endpoints {
            guard let url = URL(string: urlStr) else { continue }
            var request = URLRequest(url: url)
            // Use a modern Chrome UA — Yahoo tends to block old/iOS UAs recently
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("https://finance.yahoo.com/", forHTTPHeaderField: "Referer")
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            request.setValue("tr-TR,tr;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
            request.timeoutInterval = 8

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
                    print("BistService Yahoo [\(urlStr)]: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    continue
                }
                let stocks = parseQuoteResponse(data: data)
                if !stocks.isEmpty {
                    print("BistService: Yahoo succeeded with \(stocks.count) stocks")
                    return stocks
                }
            } catch {
                print("BistService Yahoo error: \(error.localizedDescription)")
            }
        }
        return []
    }

    private func parseQuoteResponse(data: Data) -> [Stock] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quoteResponse = json["quoteResponse"] as? [String: Any],
              let result = quoteResponse["result"] as? [[String: Any]] else { return [] }

        var stocks: [Stock] = []
        for item in result {
            guard let symbolRaw = item["symbol"] as? String,
                  let price = item["regularMarketPrice"] as? Double,
                  price > 0 else { continue }

            let sym = symbolRaw.replacingOccurrences(of: ".IS", with: "")
            let change = item["regularMarketChangePercent"] as? Double ?? 0
            let volume = item["regularMarketVolume"] as? Double ?? 0
            let high = (item["regularMarketDayHigh"] as? NSNumber)?.doubleValue ?? price
            let low = (item["regularMarketDayLow"] as? NSNumber)?.doubleValue ?? price
            let name = (item["longName"] as? String
                ?? item["shortName"] as? String
                ?? knownStocks.first(where: { $0.symbol == sym })?.name
                ?? sym)

            // Financial Metrics (Extra)
            let mktCap = (item["marketCap"] as? NSNumber)?.doubleValue ?? 0
            let pe = (item["trailingPE"] as? NSNumber)?.doubleValue ?? (item["forwardPE"] as? NSNumber)?.doubleValue
            let pb = (item["priceToBook"] as? NSNumber)?.doubleValue
            let div = (item["trailingAnnualDividendYield"] as? NSNumber)?.doubleValue

            stocks.append(Stock(
                symbol: sym,
                description: name,
                lastPrice: String(format: "%.2f", price),
                changePercent: String(format: "%@%.2f%%", change >= 0 ? "+" : "", change),
                volume: formatVolume(volume),
                highPrice: String(format: "%.2f", high),
                lowPrice: String(format: "%.2f", low)
            ))
        }
        return stocks
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 { return String(format: "%.1fM", volume / 1_000_000) }
        if volume >= 1_000 { return String(format: "%.1fK", volume / 1_000) }
        return String(format: "%.0f", volume)
    }

    private func formatMarketCap(_ mktCap: Double) -> String? {
        guard mktCap > 0 else { return nil }
        if mktCap >= 1_000_000_000 {
            return String(format: "₺%.1f Mlyr", mktCap / 1_000_000_000)
        } else if mktCap >= 1_000_000 {
            return String(format: "₺%.1f Mln", mktCap / 1_000_000)
        }
        return String(format: "₺%.0f", mktCap)
    }

    // Fallback: fetch individual symbols one-by-one from Yahoo Finance chart endpoint
    // This is more reliable than the batch quotes endpoint
    private func fetchFallbackQuotes(symbols: [String]) async -> [Stock] {
        var stocks: [Stock] = []
        
        let chunkSize = 5
        for i in stride(from: 0, to: symbols.count, by: chunkSize) {
            let chunk = Array(symbols[i..<min(i + chunkSize, symbols.count)])
            
            await withTaskGroup(of: Stock?.self) { group in
                for symbol in chunk {
                    group.addTask {
                        await self.fetchSingleQuote(symbol: symbol)
                    }
                }
                
                for await stock in group {
                    if let stock = stock {
                        stocks.append(stock)
                    }
                }
            }
            
            // Add a small delay between chunks to avoid quick connection exhaustion
            if i + chunkSize < symbols.count {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        if !stocks.isEmpty {
            print("BistService fallback: fetched \(stocks.count) stocks individually")
        }
        return stocks
    }

    private func fetchSingleQuote(symbol: String) async -> Stock? {
        // Use Yahoo chart endpoint per-symbol — more reliable than batch quotes for BIST
        let ts = Int(Date().timeIntervalSince1970)
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol).IS?range=1d&interval=1d&includePrePost=false&_=\(ts)"
        guard let url = URL(string: urlStr) else { return nil }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.yahoo.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 6
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let result = chart["result"] as? [[String: Any]],
              let first = result.first,
              let meta = first["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double,
              price > 0 else { return nil }
        
        let prevClose = meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double ?? price
        let high = meta["regularMarketDayHigh"] as? Double ?? price
        let low = meta["regularMarketDayLow"] as? Double ?? price
        let volume = meta["regularMarketVolume"] as? Double ?? 0
        let change = prevClose > 0 ? ((price - prevClose) / prevClose) * 100.0 : 0.0
        let name = knownStocks.first(where: { $0.symbol == symbol })?.name ?? symbol
        
        // Extra Metrics for Fallback
        let mktCap = meta["marketCap"] as? Double ?? 0
        let pe = meta["trailingPE"] as? Double 
        let pb = meta["priceToBook"] as? Double
        let div = meta["trailingAnnualDividendYield"] as? Double

        return Stock(
            symbol: symbol,
            description: name,
            lastPrice: String(format: "%.2f", price),
            changePercent: String(format: "%@%.2f%%", change >= 0 ? "+" : "", change),
            volume: formatVolume(volume),
            highPrice: String(format: "%.2f", high),
            lowPrice: String(format: "%.2f", low)
        )
    }

    // MARK: - Historical Prices
    public func fetchHistoricalPrices(symbol: String, period: String) async throws -> [Double] {
        var range = "1d"; var interval = "5m"
        switch period {
        case "1G": range = "1d"; interval = "5m"
        case "1H": range = "5d"; interval = "60m"
        case "1A": range = "1mo"; interval = "1d"
        case "1Y": range = "1y"; interval = "1wk"
        case "Tümü": range = "max"; interval = "1mo"
        default: break
        }

        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol).IS?range=\(range)&interval=\(interval)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let chart = json["chart"] as? [String: Any],
           let result = chart["result"] as? [[String: Any]],
           let first = result.first,
           let indicators = first["indicators"] as? [String: Any],
           let quote = indicators["quote"] as? [[String: Any]],
           let q = quote.first,
           let closes = q["close"] as? [Double?] {
            return closes.compactMap { $0 }
        }
        return []
    }
}

