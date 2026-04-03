import Foundation
import Combine
import SwiftUI

@MainActor
public final class BistViewModel: ObservableObject {
    @Published public private(set) var stocks: [Stock] = []
    @Published public private(set) var searchedStocks: [Stock] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isSearching: Bool = false
    @Published public var searchText: String = ""

    private var cancellables = Set<AnyCancellable>()

    public var displayStocks: [Stock] {
        searchText.isEmpty ? stocks : searchedStocks
    }

    public var topGainers: [Stock] {
        stocks.filter { parseChange($0.changePercent) != nil }
            .sorted { (parseChange($0.changePercent) ?? 0) > (parseChange($1.changePercent) ?? 0) }
            .prefix(10).map { $0 }
    }

    public var topLosers: [Stock] {
        stocks.filter { parseChange($0.changePercent) != nil }
            .sorted { (parseChange($0.changePercent) ?? 0) < (parseChange($1.changePercent) ?? 0) }
            .prefix(10).map { $0 }
    }

    public var topVolume: [Stock] {
        stocks.filter { parseVolume($0.volume) > 0 }
            .sorted { parseVolume($0.volume) > parseVolume($1.volume) }
            .prefix(10).map { $0 }
    }

    private func parseChange(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "+", with: ""))
    }

    private func parseVolume(_ s: String) -> Double {
        let clean = s.uppercased()
        if clean.hasSuffix("M"), let v = Double(clean.dropLast()) { return v * 1_000_000 }
        if clean.hasSuffix("K"), let v = Double(clean.dropLast()) { return v * 1_000 }
        return Double(clean) ?? 0
    }

    private let bistService: BistServicing

    public init(bistService: BistServicing? = nil) {
        self.bistService = bistService ?? BistService.shared
        setupSearch()
    }

    private func setupSearch() {
        $searchText
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                if text.isEmpty {
                    self.searchedStocks = []
                    self.isSearching = false
                } else {
                    self.isSearching = true
                    Task {
                        let results = await self.bistService.searchStocks(query: text)
                        self.searchedStocks = results
                        self.isSearching = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    public func loadData() async {
        isLoading = true
        let fetchedStocks = await bistService.fetchStocks(forceRefresh: false)
        self.stocks = fetchedStocks
        isLoading = false
    }
}

