import Foundation
import Combine
import SwiftUI

@MainActor
public final class CryptoViewModel: ObservableObject {
    @Published public private(set) var cryptos: [Crypto] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public var searchText: String = "" {
        didSet {
            scheduleSubscribe()
        }
    }
    
    // Bağımlılıklar (Dependencies)
    private let cryptoService: CryptoServicing
    private let webSocketClient: WebSocketClienting
    private var subscribeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public var filteredCryptos: [Crypto] {
        if searchText.isEmpty {
            return cryptos
        } else {
            return cryptos.filter { $0.symbol.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    public var topPopular: [Crypto] {
        let popular = CryptoService.popularPairs
        return cryptos.filter { popular.contains($0.symbol.uppercased()) }
            .sorted {
                let idx1 = popular.firstIndex(of: $0.symbol.uppercased()) ?? Int.max
                let idx2 = popular.firstIndex(of: $1.symbol.uppercased()) ?? Int.max
                return idx1 < idx2
            }
    }
    
    public var topGainers: [Crypto] {
        cryptos.sorted { (Double($0.priceChangePercent) ?? 0) > (Double($1.priceChangePercent) ?? 0) }.prefix(10).map { $0 }
    }
    
    public var topLosers: [Crypto] {
        cryptos.sorted { (Double($0.priceChangePercent) ?? 0) < (Double($1.priceChangePercent) ?? 0) }.prefix(10).map { $0 }
    }
    
    public var topVolume: [Crypto] {
        cryptos.sorted { (Double($0.volume) ?? 0) > (Double($1.volume) ?? 0) }.prefix(10).map { $0 }
    }

    public init(cryptoService: CryptoServicing? = nil, webSocketClient: WebSocketClienting? = nil) {
        self.cryptoService = cryptoService ?? CryptoService.shared
        self.webSocketClient = webSocketClient ?? WebSocketClient.shared
        
        setupLivePrices()
    }
    
    public func loadData() async {
        isLoading = true
        errorMessage = nil
        
        let fetchedCryptos = await cryptoService.fetchAll24hTickers(cachePolicy: .useCacheIfAvailable)
        
        // Sadece USDT paritelerini al, popüler olanları öne çıkar, kalanları hacme göre sırala
        self.cryptos = CryptoService.sortCryptos(fetchedCryptos)
        
        Task {
            await webSocketClient.connect()
            scheduleSubscribe()
        }
        
        isLoading = false
    }
    
    private func setupLivePrices() {
        webSocketClient.pricePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tick in
                self?.updateCryptoPrice(tick)
            }
            .store(in: &cancellables)
    }
    
    private func scheduleSubscribe() {
        subscribeTask?.cancel()
        subscribeTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms geciktirme (debounce)
            if Task.isCancelled { return }
            let symbols = self.filteredCryptos.prefix(50).map { $0.symbol }
            await self.webSocketClient.subscribe(symbols: symbols)
        }
    }
    
    private func updateCryptoPrice(_ tick: WebSocketPriceTick) {
        let symbol = tick.symbol.uppercased()
        if let idx = cryptos.firstIndex(where: { $0.symbol.uppercased() == symbol }) {
            let old = cryptos[idx]
            cryptos[idx] = Crypto(
                symbol: old.symbol,
                lastPrice: tick.price,
                priceChangePercent: tick.priceChangePercent ?? old.priceChangePercent,
                highPrice: old.highPrice,
                lowPrice: old.lowPrice,
                volume: old.volume
            )
        }
    }
    
    public func formatPrice(_ priceString: String) -> String {
        guard let value = Double(priceString) else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        
        if value < 0.0001 {
            formatter.maximumFractionDigits = 8
        } else if value < 1 {
            formatter.maximumFractionDigits = 4
        } else {
            formatter.maximumFractionDigits = 2
        }
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    public func formatChange(_ changeString: String) -> String {
        guard let value = Double(changeString) else { return "0.00%" }
        let prefix = value > 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, value)
    }
}
